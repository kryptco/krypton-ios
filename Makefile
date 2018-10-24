check:
	set -o pipefail && xcodebuild test -project Krypton.xcodeproj -scheme Debug -destination 'platform=iOS Simulator,name=iPhone X' | xcpretty
