check:
	xcodebuild test -project Krypton.xcodeproj -scheme Debug -destination 'platform=iOS Simulator,name=iPhone 7' | xcpretty
