#!/bin/sh

buildNumber=$(git rev-list --count HEAD)

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "Krypton/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "Notify/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "NotifyUI/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "LastCommand/Info.plist"

echo "Updated targets to build: $buildNumber"