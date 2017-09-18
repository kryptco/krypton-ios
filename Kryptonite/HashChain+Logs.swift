//
//  HashChain+Logs.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

extension HashChain {
    
    struct ReadLogs:Jsonable {
        let teamPointer:TeamPointer
        let memberPublicKey:SodiumBoxPublicKey?
        
        init(teamPointer:TeamPointer, lastEncryptedLogHash:Data, unixSeconds:UInt64) {
            self.teamPointer = teamPointer
            self.nonce = nonce
            self.unixSeconds = unixSeconds
        }
        
        init(json: Object) throws {
            try self.init(teamPointer: TeamPointer(json: json ~> "team_pointer"),
                          nonce: ((json ~> "nonce") as String).fromBase64(),
                          unixSeconds: json ~> "unix_seconds")
        }
        
        var object: Object {
            return ["team_pointer": teamPointer.object,
                    "nonce": nonce.toBase64(),
                    "unix_seconds": unixSeconds]
        }

    }
    
    
    
    /*enum Payload {
        //... continued from api.md
        ReadLogs(ReadLogs),
        CreateLogChain(CreateLogChain),
        AppendLog(LogOperation),
    }
    
    struct CreateLogChain {
        team_public_key: [u8],
        wrapped_keys: [WrappedKey],
    }
    
    enum LogOperation {
        AddWrappedKeys([WrappedKey])    //  encrypt current symmetric key to new admin
        RotateKey([WrappedKey])         //  change symmetric key when an admin is removed
        EncryptLog(EncryptedLog)        //  using current symmetric key
    }
    
    struct WrappedKey {
        public_key: [u8],   //  admin_pk
        ciphertext: [u8],   //  box(member_sk, admin_pk, symmetric_key)
    }
    
    struct EncryptedLog {
        last_log_hash: [u8],
        ciphertext: [u8],       //  symmetric encryption
    }
    
    struct ReadLogs {
        last_encrypted_log_hash: Option<[u8]>,
        team: [u8],                       // team_public_key or hash of any block on team chain
        member_public_key: Option<[u8]>,        // None => all members -- allows members to read own logs
    }*/
    
    

}
