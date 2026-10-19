#!/usr/bin/env bash
# Prints udid=<id> to $GITHUB_OUTPUT for an iPhone simulator on the given iOS
# version, downloading the runtime first when asked. Fails when none can be made,
# so a missing runtime fails the job instead of skipping the tests.
#   prepare-simulator.sh <ios-version> <device-name> [download]
set -euo pipefail

version="$1"
device="$2"
download="${3:-}"
runtime="com.apple.CoreSimulator.SimRuntime.iOS-${version//./-}"

if [ "$download" = "true" ] && ! xcrun simctl list runtimes | grep -q "$runtime"; then
  echo "Downloading iOS $version runtime"
  xcodebuild -downloadPlatform iOS -buildVersion "$version"
fi

xcrun simctl list runtimes
if ! xcrun simctl list runtimes | grep -q "$runtime"; then
  echo "::error::iOS $version simulator runtime is not available"
  exit 1
fi

udid=$(xcrun simctl create "$device ($version)" "$device" "$runtime")
echo "Created $device on iOS $version: $udid"
echo "udid=$udid" >> "$GITHUB_OUTPUT"
