//
//  TeamDataManagerTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Kryptonite

enum X {
    case a(String)
}

class TeamDataManagerTests: XCTestCase {
    
    var id:Data!
    var teamPublicKey:Data!
    
    var members:[Team.MemberIdentity]!
    var team:Team!
    
    var randomBlock:SigChain.Block {
        let randomPayload = try! Data.random(size: 256).toBase64()
        return try! SigChain.Block(publicKey:teamPublicKey, payload: randomPayload, signature: Data.random(size: 256))
    }
    
    override func setUp() {
        super.setUp()
        id = try! Data.random(size: 16)
        teamPublicKey = try! Data.random(size: 32)
        let users = ["eve@acme.co", "don@acme.co", "carlos@acme.co", "bob@acme.co", "alice@acme.co"]
        members = users.map {
            return try! Team.MemberIdentity(publicKey: Data.random(size: 32), encryptionPublicKey: Data.random(size: 32), email: $0, sshPublicKey: Data.random(size: 32), pgpPublicKey: Data.random(size: 32))
        }
        
        team = Team(info: Team.Info(name: "test team"))
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateTeam() {
        do {
            let dm = try TeamDataManager(teamID: id)

            try dm.create(team: team, creator: members[0], block: randomBlock)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testConflicts() {
        do {
            let dm = try TeamDataManager(teamID: id)

            try dm.create(team: team, creator: members[0], block: randomBlock)
            try dm.saveContext()
            
        } catch {
            XCTFail("\(error)")
        }
        
        let b1 = SigChain.Block(publicKey: teamPublicKey, payload: "some 1", signature: try! Data.random(size: 64))
        let b2 = SigChain.Block(publicKey: teamPublicKey, payload: "some 2", signature: try! Data.random(size: 64))

        do {
            let dm1 = try TeamDataManager(teamID: id)
            try dm1.append(block: b1)
            
            let dm2 = try TeamDataManager(teamID: id)
            try dm2.append(block: b2)
            
            try dm1.saveContext()
            try dm2.saveContext()

            XCTFail("Error: should have found conflicts")
        } catch {
        }
        
        do {
            let dm1 = try TeamDataManager(teamID: id)
            try dm1.append(block: b1)
            try dm1.saveContext()
            
            let dm2 = try TeamDataManager(teamID: id)
            try dm2.append(block: b2)
            try dm2.saveContext()
        } catch {
            XCTFail("\(error)")
        }

    }
    
    func testMultiDataManager() {
        
        do {

            let dm = try TeamDataManager(teamID: id)
            try dm.create(team: team, creator: members[0], block: randomBlock)
            
            // b1
            let block1 = randomBlock
            try dm.append(block: block1)
            try dm.saveContext()
            
            let dmx = try TeamDataManager(teamID: id)
            _ = try dmx.fetchTeam()
            
            let dmz = try TeamDataManager(teamID: id)
            try XCTAssert(dmz.lastBlockHash() == block1.hash())
            
            // b2
            let block2 = randomBlock
            try dm.append(block: block2)
            try dm.saveContext()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    
    func testTeamChanges() {
        let dm = try! TeamDataManager(teamID: id)
        
        let updateApproval:UInt64 = 600
        let updateName = "Test Team 2"

        do {
            try dm.create(team: team, creator: members[0], block: randomBlock)
            let _ = try dm.fetchTeam()
            
            // policy
            var updated:Team = team
            updated.policy = Team.PolicySettings(temporaryApprovalSeconds: updateApproval)
            let block1 = randomBlock
            
            try dm.set(team: updated)
            try dm.append(block: block1)
            try dm.saveContext()
            
            let dmx = try TeamDataManager(teamID: id)
            _ = try dmx.fetchTeam()
            
            let dmz = try TeamDataManager(teamID: id)
            try XCTAssert(dmz.lastBlockHash() == block1.hash())

            // name
            updated.info = Team.Info(name: updateName)
            let block2 = randomBlock
            
            try dm.set(team: updated)
            try dm.append(block: block2)
            try dm.saveContext()
        } catch {
            XCTFail("\(error)")
        }
    }
    

    
    func testBlocks() {
        do {
            let dm = try TeamDataManager(teamID: id)
            try dm.create(team: team, creator: members[0], block: randomBlock)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testCheckpointTest() {
        
        do {
            let dm = try TeamDataManager(teamID: id)

            let createBlock = randomBlock
            try dm.create(team: team, creator: members[0], block: createBlock)
            
            let block1 = randomBlock
            try dm.append(block: block1)
            
            let block2 = randomBlock
            try dm.append(block: block2)

            try dm.saveContext()
            
            try XCTAssert(dm.hasBlock(for: block2.hash()))

            try XCTAssert(dm.hasBlock(for: createBlock.hash()))
            try XCTAssert(dm.hasBlock(for: block1.hash()))

            
        } catch {
            XCTFail("\(error)")
        }
    }

    
    func testCreateMember() {
        do {
            let dm = try TeamDataManager(teamID: id)

            try dm.create(team: team, creator: members[0], block: randomBlock)
            
            let member = (try dm.fetchAll() as [Team.MemberIdentity])[0]
            
            XCTAssert(member.publicKey == members[0].publicKey)
            
        } catch {
            XCTFail("\(error)")
        }
    }



    func testMembers() {
        _ = Team(info: Team.Info(name: "test team"))
        
    }
    
    func testPinnedHosts() {
        let team = Team(info: Team.Info(name: "test team"))
        let createPayload = try! SigChain.CreateChain(creator: members[0], teamInfo: team.info).jsonString()
        let createSignature = try! Data.random(size: 64)
        let createBlock = SigChain.Block(publicKey: members[0].publicKey, payload: createPayload, signature: createSignature)
        
        do {
            let dm = try TeamDataManager(teamID: id)
            
            try dm.create(team: team, creator: members[0], block: createBlock)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
}
