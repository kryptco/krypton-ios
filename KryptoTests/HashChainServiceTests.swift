//
//  HashChainServiceTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/3/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
import UIKit

class HashChainServiceTests: XCTestCase {
    
    var teamIdentity:TeamIdentity!
    var service:HashChainService!
    
    override func setUp() {
        super.setUp()
        
        //make sure we have key
        if !KeyManager.hasKey() {
            try! KeyManager.generateKeyPair(type: .Ed25519)
        }
        
        // create the team
        let teamKeypair = try! KRSodium.shared().sign.keyPair()!
        let team = try! Team(name: "iOSTests", publicKey: teamKeypair.publicKey)
        try! team.setAdmin(keypair: teamKeypair)
        
        teamIdentity = try! TeamIdentity(email: "bob@iostests.com", team: team)
        service = HashChainService(teamIdentity: teamIdentity)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateTeamAndAddMemberAdmin() {
        let exp = expectation(description: "HashChainService ASYNC request")

        do {
            try service.create(team: teamIdentity.team) { (response) in
                
                switch response {
                case .error(let e):
                    XCTFail("FAIL - Server error: \(e)")
                
                case .result(let success):
                    guard success else {
                        XCTFail("FAIL - unknown error")
                        return
                    }
                    
                    // add the admin
                    do {
                        let keyManager = try KeyManager.sharedInstance()
                        let adminMember = try Team.MemberIdentity(publicKey: self.teamIdentity.keyPair.publicKey,
                                                                  email: self.teamIdentity.email,
                                                                  sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                                                  pgpPublicKey: keyManager.loadPGPPublicKey(for: self.teamIdentity.email).packetData)
                        
                        try self.service.add(member: adminMember) { (response) in
                            
                            switch response {
                            case .error(let e):
                                XCTFail("FAIL - Server error: \(e)")
                                
                            case .result    (let success):
                                guard success else {
                                    XCTFail("FAIL - unknown error")
                                    return
                                }
                                
                                exp.fulfill()
                            }
                        }
                        
                    } catch {
                        XCTFail("FAIL: \(error)")
                    }
                }
            }
            
        } catch {
            XCTFail("FAIL: \(error)")
        }
        
        waitForExpectations(timeout: 10.0) { (error) in
            if let e = error {
                XCTFail("FAIL - callback timeout: \(e)")
            }
        }
    }
    
}
