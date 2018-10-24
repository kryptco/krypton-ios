//
//  TeamDataManagerTests.swift
//  Krypton
//
//  Created by Alex Grinman on 8/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Krypton

class TeamDataManagerTests: XCTestCase {
    
    var id:Data!
    var teamPublicKey:Data!
    
    var members:[SigChain.Identity]!
    var team:Team!
    
    var randomBlock:SigChain.SignedMessage {
        let randomPayload = try! Data.random(size: 256).toBase64()
        return try! SigChain.SignedMessage(publicKey:teamPublicKey, message: randomPayload, signature: Data.random(size: 256))
    }
    
    struct BareBlock {
        let publicKey:Data
        let message:Data
        
        func hash() -> Data {
            var data = Data()
            data.append(publicKey.SHA256)
            data.append(message.SHA256)
            
            return data.SHA256
        }
    }
    
    override func setUp() {
        super.setUp()
        id = try! Data.random(size: 16)
        teamPublicKey = try! Data.random(size: 32)
        let users = ["eve@acme.co", "don@acme.co", "carlos@acme.co", "bob@acme.co", "alice@acme.co"]
        members = users.map {
            return try! SigChain.Identity(publicKey: Data.random(size: 32).bytes, encryptionPublicKey: Data.random(size: 32).bytes, email: $0, sshPublicKey: Data.random(size: 32), pgpPublicKey: Data.random(size: 32))
        }
        
        team = Team(info: SigChain.TeamInfo(name: "test team"))
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func newTeamDataManager() throws -> TeamDataManager {
        return try TeamDataManager(name: Data.random(size: 16).toBase64(true))
    }
    
    func defaultTeamDataManager() throws -> TeamDataManager {
        return try TeamDataManager(name: id.toBase64(true))
    }
    
    func testCrossDBRead() {
        do {
            let dm1 = try newTeamDataManager()
            let dm2 = try newTeamDataManager()

            try dm1.create(team: team, creator: members[0], block: randomBlock)
            try dm2.create(team: team, creator: members[1], block: randomBlock)
            
            let admins1 = try dm1.fetchAdmins()
            print("\(admins1)")
            let admins2 = try dm2.fetchAdmins()
            print("\(admins2)")
            
        } catch {
            XCTFail("\(error)")
        }
    }

    
    func testCreateTeam() {
        do {
            let dm = try defaultTeamDataManager()

            try dm.create(team: team, creator: members[0], block: randomBlock)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testConflicts() {
        do {
            let dm = try defaultTeamDataManager()

            try dm.create(team: team, creator: members[0], block: randomBlock)
            try dm.saveContext()
            
        } catch {
            XCTFail("\(error)")
        }
        
        let b1 = SigChain.SignedMessage(publicKey: teamPublicKey, message: "some 1", signature: try! Data.random(size: 64))
        let b2 = SigChain.SignedMessage(publicKey: teamPublicKey, message: "some 2", signature: try! Data.random(size: 64))

        do {
            let dm1 = try defaultTeamDataManager()
            try dm1.append(block: b1)
            
            let dm2 = try defaultTeamDataManager()
            try dm2.append(block: b2)
            
            try dm1.saveContext()
            try dm2.saveContext()

            XCTFail("Error: should have found conflicts")
        } catch {
        }
        
        do {
            let dm1 = try defaultTeamDataManager()
            try dm1.append(block: b1)
            try dm1.saveContext()
            
            let dm2 = try defaultTeamDataManager()
            try dm2.append(block: b2)
            try dm2.saveContext()
        } catch {
            XCTFail("\(error)")
        }

    }
    
    func testMultiDataManager() {
        
        do {

            let dm = try defaultTeamDataManager()
            try dm.create(team: team, creator: members[0], block: randomBlock)
            
            // b1
            let block1 = randomBlock
            try dm.append(block: block1)
            try dm.saveContext()
            
            let dmx = try defaultTeamDataManager()
            _ = try dmx.fetchTeam()
            
            let dmz = try defaultTeamDataManager()
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
        let dm = try! defaultTeamDataManager()
        
        let updateApproval:SigChain.UTCTime = 600
        let updateName = "Test Team 2"

        do {
            try dm.create(team: team, creator: members[0], block: randomBlock)
            let _ = try dm.fetchTeam()
            
            // policy
            var updated:Team = team
            updated.policy = SigChain.Policy(temporaryApprovalSeconds: updateApproval)
            let block1 = randomBlock
            
            try dm.set(team: updated)
            try dm.append(block: block1)
            try dm.saveContext()
            
            let dmx = try defaultTeamDataManager()
            _ = try dmx.fetchTeam()
            
            let dmz = try defaultTeamDataManager()
            try XCTAssert(dmz.lastBlockHash() == block1.hash())

            // name
            updated.info = SigChain.TeamInfo(name: updateName)
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
            let dm = try defaultTeamDataManager()
            try dm.create(team: team, creator: members[0], block: randomBlock)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testFetchBlocksAfter() {
        do {
            let dm = try defaultTeamDataManager()
            try dm.create(team: team, creator: members[0], block: randomBlock)
            try dm.saveContext()
            
            for i in 0 ..< 10 {
                let block = SigChain.SignedMessage(publicKey: Data(), message: "\(i)", signature: Data())
                try dm.append(block: block)
                try dm.saveContext()
            }
            
            let bare = BareBlock(publicKey: Data(), message: Data(bytes: [UInt8]("5".utf8)))
            let blocksAfter5 = try dm.fetchBlocks(after: bare.hash())
            
            guard let block6 = blocksAfter5.first else {
                XCTFail("no blocks")
                return
            }
            
            
            guard blocksAfter5.map({ $0.message }) == ["6", "7", "8", "9"] else {
                XCTFail("unexpected block: \(block6.message)")
                return
            }
    
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testCheckpointTest() {
        
        do {
            let dm = try defaultTeamDataManager()

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
            let dm = try defaultTeamDataManager()

            try dm.create(team: team, creator: members[0], block: randomBlock)
            
            let member = (try dm.fetchAll() as [SigChain.Identity])[0]
            
            XCTAssert(member.publicKey == members[0].publicKey)
            
        } catch {
            XCTFail("\(error)")
        }
    }



    func testMembers() {
        _ = Team(info: SigChain.TeamInfo(name: "test team"))
        
    }
    
    func testPinnedHosts() {
        let team = Team(info: SigChain.TeamInfo(name: "test team"))
        let createBlock = SigChain.GenesisBlock(creator: members[0], teamInfo: team.info)
        let message = try! SigChain.Message(body: .main(.create(createBlock))).jsonString()
        let createSignature = try! Data.random(size: 64)
        let createSignedMessage = SigChain.SignedMessage(publicKey: members[0].publicKey.data, message: message, signature: createSignature)
        
        do {
            let dm = try defaultTeamDataManager()
            
            try dm.create(team: team, creator: members[0], block: createSignedMessage)
            let _ = try dm.fetchTeam()
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testCrossTeamRead() {
        
    }
    
}
