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
    
    func testConflicts() {
        let team = Team(info: Team.Info(name: "test team"))
        let createPayload = try! HashChain.CreateChain(teamPublicKey: teamPublicKey, teamInfo: team.info).jsonString()
        let createSignature = try! Data.random(size: 64)
        let createBlock = HashChain.Block(payload: createPayload, signature: createSignature)
        
        let dm = TeamDataManager(teamID: id)
        
        do {
            try dm.create(team: team, block: createBlock)
            try dm.saveContext()
            
        } catch {
            XCTFail("\(error)")
        }
        
        let b1 = HashChain.Block(payload: "some 1", signature: try! Data.random(size: 64))
        let b2 = HashChain.Block(payload: "some 2", signature: try! Data.random(size: 64))

        do {
            let dm1 = TeamDataManager(teamID: id)
            try dm1.append(block: b1)
            
            let dm2 = TeamDataManager(teamID: id)
            try dm2.append(block: b2)
            
            try dm1.saveContext()
            try dm2.saveContext()

            XCTFail("Error: should have found conflicts")
        } catch {
        }
        
        do {
            let dm1 = TeamDataManager(teamID: id)
            try dm1.append(block: b1)
            try dm1.saveContext()
            
            let dm2 = TeamDataManager(teamID: id)
            try dm2.append(block: b2)
            try dm2.saveContext()
        } catch {
            XCTFail("\(error)")
        }

    }
    
}
