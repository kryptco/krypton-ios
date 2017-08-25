//
//  TeamServiceTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/3/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
import UIKit

class TeamServiceTests: XCTestCase {
    
    var teamIdentity:TeamIdentity!
    
    override func setUp() {
        super.setUp()
        
        //make sure we have key
        if !KeyManager.hasKey() {
            try! KeyManager.generateKeyPair(type: .Ed25519)
        }
        
        // create the team
        let seed = try! Data.random(size: KRSodium.shared().sign.SeedBytes)
        let teamKeypair = try! KRSodium.shared().sign.keyPair(seed: seed)
        var team = try! Team(name: "iOSTests", publicKey: teamKeypair!.publicKey)
        team.adminKeyPairSeed = seed
        
        teamIdentity = try! TeamIdentity(email: "bob@iostests.com", team: team)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateTeamAndAddMemberAdmin() {
        let exp = expectation(description: "TeamService ASYNC request")

        var service = TeamService(teamIdentity: teamIdentity)

        do {
            try service.createTeam { (response) in
                
                switch response {
                case .error(let e):
                    XCTFail("FAIL - Server error: \(e)")
                
                case .result(let updatedTeam):
                    
                    self.teamIdentity.team = updatedTeam
                    service = TeamService(teamIdentity: self.teamIdentity)
                    // add the admin
                    do {
                        let keyManager = try KeyManager.sharedInstance()
                        let adminMember = try Team.MemberIdentity(publicKey: self.teamIdentity.keyPair.publicKey,
                                                                  email: self.teamIdentity.email,
                                                                  sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                                                  pgpPublicKey: keyManager.loadPGPPublicKey(for: self.teamIdentity.email).packetData)
                        
                        try service.add(member: adminMember) { (response) in
                            
                            switch response {
                            case .error(let e):
                                XCTFail("FAIL - Server error: \(e)")
                                
                            case .result(let updatedTeam):
                                self.teamIdentity.team = updatedTeam
                                
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
