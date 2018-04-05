//
//  VersionMatchTests.swift
//  KryptonTests
//
//  Created by Alex Grinman on 4/5/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

import XCTest
@testable import Krypton

class VersionMatchTests: XCTestCase {
    func testAppVersionMatchesXCodeVersion() {
        let appVersion = Properties.currentVersion.string;
        
        guard let xcodeVersion = Bundle(for: AppDelegate.self).infoDictionary?["CFBundleShortVersionString"] as? String
        else {
            XCTFail("Cannot read main bundle's plist version")
            return
        }
        
        XCTAssert(appVersion == xcodeVersion, "App Version \(appVersion) does not match XCode plist version \(xcodeVersion)")
    }
}
