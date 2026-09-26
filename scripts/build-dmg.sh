#!/bin/bash
# 配布用の dist/DisplayColourFilter.dmg を作る(中身はアプリと Applications フォルダへのリンク)。
# ファイル名に版番号を入れないので、最新リリースの固定リンク(releases/latest/download/DisplayColourFilter.dmg)で落とせる。
# アプリと DMG はどちらも Apple の公証を受け、公証済みの証明(チケット)を付ける(オフラインでも Gatekeeper を通るように)。
# 公証の認証情報はキーチェーンのプロファイル(既定は "DisplayColourFilter")から読む。作り方は README の Building from source
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DisplayColourFilter.app"
DMG="dist/DisplayColourFilter.dmg"
VOLUME_NAME="Display Colour Filter"
# 署名に使う ID(build-app.sh と同じもの)と、公証の認証情報を保存したキーチェーンのプロファイル名
IDENTITY="${SIGN_IDENTITY:-Developer ID Application: YOTA SHIRAISHI (L2S8LUN48M)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-DisplayColourFilter}"

[ "$IDENTITY" != "-" ] || { echo "配布用の DMG は Developer ID で署名する必要があります(SIGN_IDENTITY=- では作れません)" >&2; exit 1; }

# 公証に出して結果を待つ。通らなかったら理由(ログ)を出して止める
notarize() {
    local result status id
    result="$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)" || true
    status="$(plutil -extract status raw -o - - <<< "$result" 2>/dev/null)" || true
    if [ "$status" != "Accepted" ]; then
        echo "$result" >&2
        id="$(plutil -extract id raw -o - - <<< "$result" 2>/dev/null)" || true
        [ -z "$id" ] || xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2
        echo "公証が通りませんでした(${status:-エラー}): $1" >&2
        exit 1
    fi
    echo "Notarized: $1"
}

bash scripts/build-app.sh

# 作業フォルダはプロジェクトの外に作る(iCloud Drive 上だと余計な拡張属性が付くため)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. アプリを公証に出し、チケットを付ける
ditto -c -k --keepParent "$APP" "$WORK/DisplayColourFilter.zip"
notarize "$WORK/DisplayColourFilter.zip"
xcrun stapler staple -q "$APP"

# 2. チケット付きのアプリで DMG を作る
STAGING="$WORK/dmg"
mkdir -p "$STAGING" dist
ditto --norsrc --noextattr --noqtn "$APP" "$STAGING/DisplayColourFilter.app"
ln -s /Applications "$STAGING/Applications"
cp "build/icon/AppIcon.icns" "$STAGING/.VolumeIcon.icns"

# 書き込み可能なイメージを一度マウントし、ボリュームのアイコンをアプリのアイコンにしてから圧縮する
RW="$WORK/rw.dmg"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -format UDRW -ov "$RW" > /dev/null
MOUNT="$(hdiutil attach -nobrowse -noverify -noautoopen "$RW" | tail -1 | cut -f3-)"
xcrun SetFile -a C "$MOUNT"
hdiutil detach "$MOUNT" -quiet

rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -ov -o "$DMG" > /dev/null

# 3. DMG にも署名して公証に出し、チケットを付ける
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
notarize "$DMG"
xcrun stapler staple -q "$DMG"

# 4. Gatekeeper の判定を確かめる(公証済みの Developer ID として受け入れられること)
spctl --assess --type execute -v "$APP"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "Built: $DMG"
