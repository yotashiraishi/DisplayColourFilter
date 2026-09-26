#!/bin/bash
# アプリをビルドして build/DisplayColourFilter.app を作る
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DisplayColourFilter.app"
ICON_BUILD="build/icon"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP" "$ICON_BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICON_BUILD"

# アイコン(Icon Composer 形式)を Assets.car と AppIcon.icns にコンパイルする
xcrun actool Resources/AppIcon.icon --compile "$ICON_BUILD" \
    --output-format human-readable-text --notices --warnings \
    --output-partial-info-plist "$ICON_BUILD/partial.plist" \
    --app-icon AppIcon --include-all-app-icons \
    --enable-on-demand-resources NO --development-region en \
    --target-device mac --minimum-deployment-target 26.0 --platform macosx > /dev/null

cp "$BIN_DIR/DisplayColourFilter" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp "$ICON_BUILD/Assets.car" "$ICON_BUILD/AppIcon.icns" "$APP/Contents/Resources/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# Developer ID を持っていないのでアドホック署名(Apple silicon では署名なしだと起動できない)。
# iCloud Drive 上のフォルダだと拡張属性が付いて署名に失敗するので、先に消しておく
xattr -cr "$APP"
codesign --force --sign - "$APP"

echo "Built: $APP"
