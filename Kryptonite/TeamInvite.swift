//
//  TeamInvite.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

enum TeamJoinType {
    case invite(TeamInvite)
    case create(Request, Session)
}

struct TeamInvite {
    let initialTeamPublicKey:SodiumPublicKey
    let blockHash:Data
    let seed:Data
    
    enum Errors:Error {
        case missingArgs
    }
    
    init(initialTeamPublicKey:SodiumPublicKey, blockHash:Data, seed:Data) {
        self.initialTeamPublicKey = initialTeamPublicKey
        self.blockHash = blockHash
        self.seed = seed
    }
    
    init(path:[String]) throws {
        guard path.count >= 3 else {
            throw Errors.missingArgs
        }
        
        let initialTeamPublicKey = try SodiumPublicKey(path[0].fromBase64())
        let blockHash = try SodiumPublicKey(path[1].fromBase64())
        let seed = try path[2].fromBase64()
        
        self.init(initialTeamPublicKey: initialTeamPublicKey, blockHash: blockHash, seed: seed)
    }
}
