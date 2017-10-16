check:
	xcodebuild test -project Kryptonite.xcodeproj -scheme Debug -destination 'platform=iOS Simulator,name=iPhone 8' | xcpretty
