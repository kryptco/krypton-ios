#!/bin/sh


version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "Krypton/Info.plist")
echo "Version: $version"

read -p "RC: " rc
rc=${rc:-0}

commitNumber=$(git rev-list --count HEAD)
buildNumber="2$commitNumber.$rc"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "Krypton/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "Notify/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "NotifyUI/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "LastCommand/Info.plist"

echo "Updated targets to build number: $buildNumber"
