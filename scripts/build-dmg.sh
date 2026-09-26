#!/bin/bash
# 配布用の dist/DisplayColourFilter.dmg を作る(中身はアプリと Applications フォルダへのリンク)。
# ファイル名に版番号を入れないので、最新リリースの固定リンク(releases/latest/download/DisplayColourFilter.dmg)で落とせる
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build-app.sh

APP="build/DisplayColourFilter.app"
DMG="dist/DisplayColourFilter.dmg"
VOLUME_NAME="Display Colour Filter"

# 作業フォルダはプロジェクトの外に作る(iCloud Drive 上だと余計な拡張属性が付くため)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
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

echo "Built: $DMG"
