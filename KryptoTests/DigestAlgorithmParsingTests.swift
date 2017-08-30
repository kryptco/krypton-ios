//
//  DigestAlgorithmParsingTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/9/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Kryptonite


class DigestAlgorithmParsingTests: XCTestCase {
    
    struct testcase {
        var session:Data
        var user:String
        var digest:DigestType
        var data:SSHMessage
    }
    
    let testCaseRSA = testcase(session: try! "WtlCXAXyTdQKuTBnYTRT6obHnvB6G/kAGQclK2g4Jzc=".fromBase64(), user: "git", digest: .sha1, data: try!SSHMessage("AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()))
    
    let testCaseRSASha256 = testcase(session: try! "UUTjo7EhM6/i0iw727smr9bq+d/h2LBt1ISh4YwMH3I=".fromBase64(), user: "testuser", digest: .sha256, data: try! SSHMessage("AAAAIFFE46OxITOv4tIsO9u7Jq/W6vnf4diwbdSEoeGMDB9yMgAAAAh0ZXN0dXNlcgAAAA5zc2gtY29ubmVjdGlvbgAAAAlwdWJsaWNrZXkBAAAADHJzYS1zaGEyLTI1Ng==".fromBase64()))
    
    let testCaseRSASha512 = testcase(session: try! "mmWe3ZJGE+1hCoV9lwnCxJisggxoCM7GFOWsz/M1XpY=".fromBase64(), user: "root", digest: .sha512, data: try! SSHMessage("AAAAIJplnt2SRhPtYQqFfZcJwsSYrIIMaAjOxhTlrM/zNV6WMgAAAARyb290AAAADnNzaC1jb25uZWN0aW9uAAAACXB1YmxpY2tleQEAAAAMcnNhLXNoYTItNTEy".fromBase64()))

    let testCaseEd25519 = testcase(session: try! "AVdBTzgU4SB5cnSf9/DMaTnxLR0Sk/4kF3+xkXyQshE=".fromBase64(), user: "root", digest: .ed25519, data: try! SSHMessage("AAAAIAFXQU84FOEgeXJ0n/fwzGk58S0dEpP+JBd/sZF8kLIRMgAAAARyb290AAAADnNzaC1jb25uZWN0aW9uAAAACXB1YmxpY2tleQEAAAALc3NoLWVkMjU1MTk=".fromBase64()))
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testParseSSHUserAuthMessages() {
        
        for test in [testCaseRSA, testCaseRSASha256, testCaseRSASha512, testCaseEd25519] {
            
            do {
                let (session, user, digestType) = try SignRequest.parse(requestData: test.data)
                
                XCTAssertEqual(session, test.session)
                XCTAssertEqual(user, test.user)
                XCTAssertEqual(digestType, test.digest)
                
            } catch {
                XCTFail("error: \(error)")
            }
            
        }

    }
    
    func testBadSSHMessageParsingWrongLen() {
        do {
            var correctData = try "AAAAIE5yHvfefACpf4gX/T7jFE0kbT5VFAQA5dOaa817rvN5MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            
            let session = try correctData.popData()
            let user = try correctData.popData()
            let byte = try correctData.popByte()

            // add back but leave out a few user bytes
            var data = Data(bytes: session.bigEndianByteSize())
            data.append(session)
            
            data.append(contentsOf: user.bigEndianByteSize())
            data.append(user.subdata(in: 0 ..< user.count - 2))
            data.append(contentsOf: [byte])
            data.append(correctData)
            
            let (_, _, _) = try SignRequest.parse(requestData: data)
            XCTFail("broken ssh message data parsed correctly somehow!")
        } catch {
            XCTAssert(error is SSHMessageParsingError)
        }
    }
    
    func testBadSSHMessageParsingRandomData() {
        
        let dataLength = try! "AAAAIE5yHvfefACpf4gX/T7jFE0kbT5VFAQA5dOaa817rvN5MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64().count

        for _ in 0 ..< 9 {
            do {
                let randomData = try Data.random(size: dataLength)
                let (_, _, _) = try SignRequest.parse(requestData: randomData)
                XCTFail("random ssh message data parsed correctly somehow!")                
            } catch {
                XCTAssert(error is SSHMessageParsingError)
            }
        }
    }

    
}
