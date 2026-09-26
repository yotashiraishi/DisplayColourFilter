#!/bin/bash
# アプリをビルドして build/DisplayColourFilter.app を作る
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DisplayColourFilter.app"
ICON_BUILD="build/icon"
# 署名に使う ID(配布用の Developer ID。公証に必要)。
# 持っていない人がソースからビルドするときは SIGN_IDENTITY=- を付けるとアドホック署名になる
IDENTITY="${SIGN_IDENTITY:-Developer ID Application: YOTA SHIRAISHI (L2S8LUN48M)}"
# 組み立てと署名はプロジェクトの外で行う(iCloud Drive 上だと、消してもすぐに拡張属性が付け直されて署名に失敗するため)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/DisplayColourFilter.app"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP" "$ICON_BUILD"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" "$STAGE/Contents/Frameworks" "$ICON_BUILD"

# アイコン(Icon Composer 形式)を Assets.car と AppIcon.icns にコンパイルする
xcrun actool Resources/AppIcon.icon --compile "$ICON_BUILD" \
    --output-format human-readable-text --notices --warnings \
    --output-partial-info-plist "$ICON_BUILD/partial.plist" \
    --app-icon AppIcon --include-all-app-icons \
    --enable-on-demand-resources NO --development-region en \
    --target-device mac --minimum-deployment-target 26.0 --platform macosx > /dev/null

cp "$BIN_DIR/DisplayColourFilter" "$STAGE/Contents/MacOS/"
cp Resources/Info.plist "$STAGE/Contents/"
cp "$ICON_BUILD/Assets.car" "$ICON_BUILD/AppIcon.icns" "$STAGE/Contents/Resources/"
cp -R Resources/*.lproj "$STAGE/Contents/Resources/"
# アップデート用の Sparkle(シンボリックリンクを保ったままコピーする)
ditto "$BIN_DIR/Sparkle.framework" "$STAGE/Contents/Frameworks/Sparkle.framework"

# コピー元から付いてきた拡張属性があると署名に失敗するので、先に消しておく
xattr -cr "$STAGE"
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$STAGE"
else
    # 公証の条件(Hardened Runtime・タイムスタンプ)を付けて、Sparkle の中の部品から外側へ順に署名する。
    # Downloader.xpc は Sparkle が付けた権限(エンタイトルメント)を残す(Sparkle の説明どおり)
    SPARKLE="$STAGE/Contents/Frameworks/Sparkle.framework"
    SIGN=(codesign --force --sign "$IDENTITY" --options runtime --timestamp)
    "${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
    "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
    "${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
    "${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
    "${SIGN[@]}" "$SPARKLE"
    "${SIGN[@]}" "$STAGE"
fi
codesign --verify --deep --strict "$STAGE"
ditto "$STAGE" "$APP"

echo "Built: $APP"
