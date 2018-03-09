//
//  TeamIdentityTests.swift
//  KryptonTests
//
//  Created by Alex Grinman on 2/14/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import XCTest
@testable import Krypton

class TeamIdentityTests: XCTestCase {
    
    func testDirectInviteTeamHijack() {
        var (alice, createA) = try! TeamIdentity.newAdmin(email: "a@alice.co", teamName: "A")
        
        var (bob, createB) = try! TeamIdentity.newAdmin(email: "b@bob.co", teamName: "B")
        var eve = try! TeamIdentity.newMember(email: "e@bob.co", checkpoint: createB.hash(), initialTeamPublicKey: bob.publicKey)
        
        let directInvite = try! alice.sign(body: .main(.append(SigChain.Block(lastBlockHash: createB.hash(), operation: .invite(.direct(SigChain.DirectInvitation(publicKey: eve.publicKey, email: "e@bob.co")))))))
        
        do {
            try bob.dataManager.withTransaction { try bob.verifyAndProcessBlocks(blocks: [directInvite], dataManager: $0) }
            XCTFail("expected reject block")
        } catch {
            
        }
        
        do {
            try eve.dataManager.withTransaction { try eve.verifyAndProcessBlocks(blocks: [createB, directInvite], dataManager: $0) }
            XCTFail("expected reject block")
        } catch {
            
        }

        do {
            try alice.dataManager.withTransaction { try alice.verifyAndProcessBlocks(blocks: [createA, directInvite], dataManager: $0) }
            XCTFail("expected reject block")
        } catch {
            
        }

    }
}
