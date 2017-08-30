//
//  TeamDataManagerTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Kryptonite

class TeamDataManagerTests: XCTestCase {
    
    var id:Data!
    var teamPublicKey:Data!
    override func setUp() {
        super.setUp()
        id = try! Data.random(size: 16)
        teamPublicKey = try! Data.random(size: 32)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateTeam() {
        let team = Team(info: Team.Info(name: "test team"))
        let createPayload = try! HashChain.CreateChain(teamPublicKey: teamPublicKey, teamInfo: team.info).jsonString()
        let createSignature = try! Data.random(size: 64)
        let createBlock = HashChain.Block(payload: createPayload, signature: createSignature)
        
        let dm = TeamDataManager(teamID: id)
        
        do {
            try dm.create(team: team, block: createBlock)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
}
