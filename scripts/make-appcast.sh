#!/bin/bash
# アップデートの配信情報 site/src/appcast.xml を作り直す(アプリはここを見て新しいバージョンを知る)。
# 先に bash scripts/build-dmg.sh で dist/DisplayColourFilter.dmg を作っておくこと。
# DMG には EdDSA 署名を付ける(秘密鍵はこの Mac のログインキーチェーンにある)。
# リリースノートは release-notes/<バージョン>/<言語>.html。利用者の言語に合うものがアプリに表示される
set -euo pipefail
cd "$(dirname "$0")/.."

# リリースノートを用意する言語(先頭の英語は、どの言語にも合わないときに使われる)
LANGS=(en ja zh-Hans zh-Hant ko fr de es)

PLIST=Resources/Info.plist
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")"
MIN_SYSTEM="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST")"
DMG=dist/DisplayColourFilter.dmg
NOTES="release-notes/$VERSION"
# GitHub の Release に添付する DMG(タグは v<バージョン>)
DOWNLOAD_URL="https://github.com/yotashiraishi/DisplayColourFilter/releases/download/v$VERSION/DisplayColourFilter.dmg"
OUT=site/src/appcast.xml

for lang in "${LANGS[@]}"; do
    [ -f "$NOTES/$lang.html" ] || { echo "リリースノートがありません: $NOTES/$lang.html" >&2; exit 1; }
done

# DMG の中のアプリが Info.plist と同じバージョンか確かめる(古い DMG に署名しないように)
MOUNT="$(mktemp -d)"
hdiutil attach -nobrowse -noverify -noautoopen -readonly -mountpoint "$MOUNT" "$DMG" > /dev/null
DMG_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$MOUNT/DisplayColourFilter.app/Contents/Info.plist")"
hdiutil detach "$MOUNT" -quiet
[ "$DMG_BUILD" = "$BUILD" ] || { echo "DMG のビルド番号($DMG_BUILD)が Info.plist($BUILD)と違います。build-dmg.sh をやり直してください" >&2; exit 1; }

# sparkle:edSignature="…" length="…" が返る
SIGNATURE="$(.build/artifacts/sparkle/Sparkle/bin/sign_update "$DMG")"

{
    cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Display Colour Filter</title>
    <item>
      <title>$VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_SYSTEM</sparkle:minimumSystemVersion>
XML
    for lang in "${LANGS[@]}"; do
        echo "      <description xml:lang=\"$lang\"><![CDATA["
        cat "$NOTES/$lang.html"
        echo "]]></description>"
    done
    cat <<XML
      <enclosure url="$DOWNLOAD_URL" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
XML
} > "$OUT"

xmllint --noout "$OUT"
echo "Updated: $OUT ($VERSION, build $BUILD)"
