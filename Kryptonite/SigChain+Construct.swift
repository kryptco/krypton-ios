//
//  SigChain+Construct.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import Sodium

enum TeamChainBlockCreateError:Error {
    case noBlockHash
    case seedToKeyPair
    case sig
}


enum SigChainLink {
    case invite(teamPublicKey:SodiumSignPublicKey, blockHash:Data, noncePrivateKey:SodiumSignSecretKey)
    
    static let scheme = "kr://"
    
    enum Path:String {
        case invite = "join_team"
    }
    
    var string:String {
        switch self {
        case .invite(let teamPublicKey, let blockHash, let noncePrivateKey):
            let path = Path.invite.rawValue
            return "\(SigChainLink.scheme)\(path)/\(teamPublicKey.toBase64())/\(blockHash.toBase64())/\(noncePrivateKey.toBase64())"
        }
    }
}

extension TeamIdentity {
    
    /**
     Create a new MemberShip Invitation Block
     
     - returns:
         - `inviteURL` string that can be used by clients to join the team
         - `SigChain.Request` that can be posted to the team server
 
     */
    func invitationBlock() throws -> (inviteURL:String, request:SigChain.Request){
        
        guard let blockHash = try self.dataManager.lastBlockHash() else {
            throw TeamChainBlockCreateError.noBlockHash
        }
        
        // create an invitation nonce keypair
        let nonceSeed = try Data.random(size: KRSodium.instance().sign.SeedBytes)
        guard let nonceKeyPair = KRSodium.instance().sign.keyPair(seed: nonceSeed) else {
            throw TeamChainBlockCreateError.seedToKeyPair
        }
        
        
        // create the block
        let invitationOperation = SigChain.Operation.inviteMember(SigChain.MemberInvitation(noncePublicKey: nonceKeyPair.publicKey))
        let inviteAppendBlock = SigChain.AppendBlock(lastBlockHash: blockHash,
                                                   operation: invitationOperation)
        
        let payload = SigChain.Payload.appendBlock(inviteAppendBlock)
        let payloadData = try payload.jsonData()
        
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: self.keyPair.secretKey) else {
            throw TeamChainBlockCreateError.sig
        }
        
        let payloadString = try payloadData.utf8String()
        
        let request = SigChain.Request(publicKey: self.keyPair.publicKey, payload: payloadString, signature: signature)
        let newBlockHash = request.block.hash()
        
        // create the url link
        let inviteLink = SigChainLink.invite(teamPublicKey: initialTeamPublicKey,
                                             blockHash: newBlockHash,
                                             noncePrivateKey: nonceKeyPair.secretKey).string
        
        return (inviteLink, request)

    }
}
