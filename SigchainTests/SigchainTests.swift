//
//  SigchainTests.swift
//  SigchainTests
//
//  Created by Alex Grinman on 2/12/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import XCTest
@testable import Krypton
import JSON

class SigchainTester: XCTestCase {
    
    
    enum Errors:Error {
        case expectedFailureForMismatchedTeam
    }
    
    var test:BlockValidationTest?
    var teamIdentity: TeamIdentity?
    var teamDataManager: TeamDataManager?
    var clientIndex:Int?
    var blockIndex:Int?
    
    
    // #workaround: https://briancoyner.github.io/2015/11/28/swift-parameterized-xctestcase.html
    override class var defaultTestSuite: XCTestSuite {
        let bundle = Bundle(for: SigchainTester.self)
        let generatedTests = try! String(contentsOfFile: bundle.path(forResource: "generated_test_cases", ofType: "json")!)
        let blockValidationTests = try! [BlockValidationTest](jsonString: generatedTests)
        
        let masterSuite = XCTestSuite(name: " ")
        
        blockValidationTests.forEach {
            
            let suite = XCTestSuite(name: $0.name
                                            .replacingOccurrences(of: "_", with: " ")
                                            .capitalized)
            
            for (clientIndex, client) in $0.clients.enumerated() {
                var teamIdentity:TeamIdentity
                teamIdentity = try! TeamIdentity(client: client)
                
                for (blockIndex, _) in $0.testBlocks.enumerated() {
                    for invocation in self.testInvocations {
                        let testCase = SigchainTester(invocation: invocation)
                        testCase.test = $0
                        testCase.teamIdentity = teamIdentity
                        testCase.clientIndex = clientIndex
                        testCase.blockIndex = blockIndex

                        suite.addTest(testCase)
                    }
                }
            }
            masterSuite.addTest(suite)
        }
        
        return masterSuite
    }
    

    func testClientOnBlock() {
        let test = self.test!
        var teamIdentity = self.teamIdentity!
        let client = self.clientIndex!
        let blockIndex = self.blockIndex!
        let block = test.testBlocks[blockIndex]
        
        let _ = XCTContext.runActivity(named: "Client \(client) on Block \(blockIndex) > Expected \"valid=\(block.expected.valid)\"")
        { _ -> Bool in
            var result:Bool
            var err:Error?
            
            do {
                try teamIdentity.dataManager.withTransaction {
                    try teamIdentity.verifyAndProcessBlocks(blocks: [block.signedMessage], dataManager: $0)
                }
                result = true
            } catch {
                self.debug(test: test, client: client, block: blockIndex, message: "\(error)")
                result = false
                err = error
            }
            
            guard teamIdentity.initialTeamPublicKey == block.expected.teamPublicKey else {
                if result {
                    self.fail(test: test, client: client, block: blockIndex,  error: Errors.expectedFailureForMismatchedTeam)
                } else {
                    self.debug(test: test, client: client, block: blockIndex, message: "Skipping test for different team chain.")
                }
                return !result
            }
            
            switch result {
            case block.expected.valid:
                self.success(test: test, client: client, block: blockIndex)
                
            default:
                self.fail(test: test, client: client, block: blockIndex, error: err)
            }

            return result == block.expected.valid
        }
    }
    
    //MARK: Helpers
    func fail(test:BlockValidationTest, client:Int, block:Int, error:Error? = nil) {
        let expected = test.testBlocks[block].expected.valid
        
        guard let err = error else  {
            XCTFail("Client\(client) on Block\(block) failed. Expected \"valid=\(expected)\". Got \(!expected).")
            return
        }
        
        XCTFail("Client\(client) on Block\(block) failed. Expected \"valid=\(expected)\". Got error: \(err).")
    }
    
    func success(test:BlockValidationTest, client:Int, block:Int) {
        print("Client\(client) on Block\(block) succeeded.")
    }
    
    func debug(test:BlockValidationTest, client:Int, block:Int, message:String) {
        print("[ \(test.name) ] Client\(client) on Block\(block). Debug: \(message)")
    }

}
