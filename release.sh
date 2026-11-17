#!/bin/bash
# Cuts a release: build, sign for distribution, notarize the app, make and notarize the
# disk image, tag, and publish both DMGs (versioned + the fixed name the README links to).
# Usage: ./release.sh   (releases the version in Info.plist.in; commit first)
set -euo pipefail
cd "$(dirname "$0")"
name=MenuBarManager
[ -z "$(git status --porcelain)" ] || { echo "Working tree is dirty; commit first." >&2; exit 1; }
VERSION=$(sed -n 's/.*CFBundleShortVersionString<\/key><string>\([^<]*\).*/\1/p' Info.plist.in)
TAG="v$VERSION"
gh release view "$TAG" >/dev/null 2>&1 && { echo "$TAG already exists; bump the version." >&2; exit 1; }

identity=$(security find-identity -v -p codesigning | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"')
profile=""
for c in "${NOTARY_PROFILE:-}" DesktopBins StayMounted NetworkToggle JumpFolder; do
  [ -n "$c" ] && xcrun notarytool history --keychain-profile "$c" >/dev/null 2>&1 && { profile=$c; break; }
done
[ -n "$profile" ] || { echo "No notarytool keychain profile works." >&2; exit 1; }

./build.sh
out=.build/release-dist; rm -rf "$out"; mkdir -p "$out"
ditto "/Applications/$name.app" "$out/$name.app"
app="$out/$name.app"
# Distribution signature: hardened runtime + secure timestamp, helper first.
codesign --force --options runtime --timestamp --sign "$identity" "$app/Contents/Helpers/MenuBarManagerHider"
codesign --force --options runtime --timestamp --sign "$identity" "$app"
ditto -c -k --keepParent "$app" "$out/notarize.zip"
xcrun notarytool submit "$out/notarize.zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
spctl -a -vv "$app"

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/$name.app"; ln -s /Applications "$stage/Applications"
dmg="$out/$name-$VERSION.dmg"
hdiutil create -quiet -srcfolder "$stage" -volname "Menu Bar Manager" -fs APFS -format ULFO "$dmg" 2>/dev/null
codesign --force --sign "$identity" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
cp "$dmg" "$out/$name.dmg"

git tag -a "$TAG" -m "Menu Bar Manager $VERSION"; git push -q origin "$TAG"
gh release create "$TAG" "$dmg" "$out/$name.dmg" --title "Menu Bar Manager $VERSION" \
  --notes "${RELEASE_NOTES:-See the commit history for what changed in $VERSION.}"
url="https://github.com/smanke-org/$name/releases/latest/download/$name.dmg"
for i in 1 2 3 4 5 6; do
  [ "$(curl -sL -o /dev/null -w '%{http_code}' "$url")" = 200 ] && { echo "$url -> 200"; echo "Released $TAG."; exit 0; }
  sleep 10
done
echo "Download link not resolving yet; check the assets." >&2; exit 1
