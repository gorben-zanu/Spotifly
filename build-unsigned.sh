#!/bin/bash
#
# Signs a Spotifly build so it runs on this Mac.
#
# The CI build in .github/workflows/build.yml has no signature at all
# (`CODE_SIGNING_ALLOWED=NO`), and an unsigned app does not launch on Apple silicon. An ad-hoc
# signature is enough, but it cannot carry the developer team's keychain access group: that
# group is granted by a provisioning profile, which an ad-hoc signature has none of. So the
# entitlements written here leave `keychain-access-groups` out, and the app stores its sign-in
# in the keychain's default group instead — which costs one sign-in, since what the release
# build stored is not readable from here.
#
# Usage: ./build-unsigned.sh [path/to/Spotifly.app]
#   Default: build/Build/Products/Debug/Spotifly.app (a local xcodebuild run)

set -euo pipefail

app="${1:-build/Build/Products/Debug/Spotifly.app}"

if [[ ! -d "$app" ]]; then
    echo "no app at $app" >&2
    echo "unzip Spotifly.zip first, then: $0 Spotifly.app" >&2
    exit 1
fi

# Guard: a build made by Xcode itself is already signed for the team, and re-signing it here
# would break the keychain group it can hold. Only the CI artifact needs this.
if codesign -dv "$app" 2>&1 | grep -q "Authority=Apple Development"; then
    echo "$app is signed for the team already; nothing to do" >&2
    exit 0
fi

# The same entitlements as Spotifly/Spotifly.entitlements, minus the keychain group. The
# sandbox stays: the app expects to be sandboxed, and its container is where the release
# build's account data lives, so keeping it reuses that.
entitlements="$(mktemp -t spotifly-entitlements).plist"
trap 'rm -f "$entitlements"' EXIT
cat > "$entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>
PLIST

# A download carries the quarantine flag; an app launched with it is asked about, or refused.
xattr -dr com.apple.quarantine "$app" 2>/dev/null || true

# The app bundles no nested code (checked against the 1.4.0 release: no frameworks, dylibs or
# XPC services), so one signature covers it.
codesign --force --sign - --entitlements "$entitlements" --timestamp=none "$app"

codesign -dv "$app" 2>&1 | grep -E "Identifier|TeamIdentifier|Signature" || true
echo "signed $app (ad-hoc)"
echo "open it: open \"$app\""
