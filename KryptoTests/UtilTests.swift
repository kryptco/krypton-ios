//
//  UtilTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 4/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Kryptonite

class UtilTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testTimeAgo() {
        let thirtyFourM = Date(timeIntervalSinceNow: -34.0 * TimeSeconds.minute.rawValue)
        let tenH = Date(timeIntervalSinceNow: -10.0 * TimeSeconds.hour.rawValue)
        let twoH46m = Date(timeIntervalSinceNow: -2.0 * TimeSeconds.hour.rawValue - 46.0 * TimeSeconds.minute.rawValue)
        let oneH12m = Date(timeIntervalSinceNow: -1.0 * TimeSeconds.hour.rawValue - 12.0 * TimeSeconds.minute.rawValue)
        let fiveD11h = Date(timeIntervalSinceNow: -5.0 * TimeSeconds.day.rawValue - 11.0 * TimeSeconds.hour.rawValue)
        let oneH59m = Date(timeIntervalSinceNow: -1.0 * TimeSeconds.hour.rawValue - 59.0 * TimeSeconds.minute.rawValue)
        let tw0H59m59s = Date(timeIntervalSinceNow: -2.0 * TimeSeconds.hour.rawValue - 59.0 * TimeSeconds.minute.rawValue - 59.0 * TimeSeconds.second.rawValue)

        for suffix in [" ago", "!", ""] {
            
            XCTAssertEqual(thirtyFourM.timeAgo(suffix: suffix), "34m\(suffix)")
            XCTAssertEqual(tenH.timeAgo(suffix: suffix), "10h\(suffix)")
            XCTAssertEqual(twoH46m.timeAgo(suffix: suffix), "2h 46m\(suffix)")
            XCTAssertEqual(oneH12m.timeAgo(suffix: suffix), "1h 12m\(suffix)")
            XCTAssertEqual(fiveD11h.timeAgo(suffix: suffix), "5d\(suffix)")
            XCTAssertEqual(oneH59m.timeAgo(suffix: suffix), "1h 59m\(suffix)")
            XCTAssertEqual(tw0H59m59s.timeAgo(suffix: suffix), "2h 59m\(suffix)")
        }
    }
    
    func testLongTimeAgo() {
        let thirtyFourM = Date(timeIntervalSinceNow: -34.0 * TimeSeconds.minute.rawValue)
        let tenH = Date(timeIntervalSinceNow: -10.0 * TimeSeconds.hour.rawValue)
        let twoH46m = Date(timeIntervalSinceNow: -2.0 * TimeSeconds.hour.rawValue - 46.0 * TimeSeconds.minute.rawValue)
        let oneH12m = Date(timeIntervalSinceNow: -1.0 * TimeSeconds.hour.rawValue - 12.0 * TimeSeconds.minute.rawValue)
        let fiveD11h = Date(timeIntervalSinceNow: -5.0 * TimeSeconds.day.rawValue - 11.0 * TimeSeconds.hour.rawValue)
        let oneH59m = Date(timeIntervalSinceNow: -1.0 * TimeSeconds.hour.rawValue - 59.0 * TimeSeconds.minute.rawValue)
        let tw0H59m59s = Date(timeIntervalSinceNow: -2.0 * TimeSeconds.hour.rawValue - 59.0 * TimeSeconds.minute.rawValue - 59.0 * TimeSeconds.second.rawValue)
        
        for suffix in [" ago", "!", ""] {
            
            XCTAssertEqual(thirtyFourM.timeAgoLong(suffix: suffix), "34 minutes\(suffix)")
            XCTAssertEqual(tenH.timeAgoLong(suffix: suffix), "10 hours\(suffix)")
            XCTAssertEqual(twoH46m.timeAgoLong(suffix: suffix), "2 hours 46m\(suffix)")
            XCTAssertEqual(oneH12m.timeAgoLong(suffix: suffix), "1 hour 12m\(suffix)")
            XCTAssertEqual(fiveD11h.timeAgoLong(suffix: suffix), "5 days\(suffix)")
            XCTAssertEqual(oneH59m.timeAgoLong(suffix: suffix), "1 hour 59m\(suffix)")
            XCTAssertEqual(tw0H59m59s.timeAgoLong(suffix: suffix), "2 hours 59m\(suffix)")
        }
    }
}
