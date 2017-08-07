//
//  HashChainService.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/1/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import SwiftHTTP

class HashChainService {
    
    enum Errors:Error {
        case badResponse
        case badInviteSeed
        
        case payloadSignature
        case needNewestBlock
        
        case missingLastBlockHash
        
        case needAdminKeypair
        case errorResponse(ServerError)
        
        case blockDidNotPost
    }
    
    struct ServerError:Error, CustomDebugStringConvertible {
        let message:String
        var debugDescription: String {
            return "Server Error(\(message))"
        }
    }
    
    enum ServerResponse<T:JsonReadable>:JsonReadable {
        case error(ServerError)
        case success(T)
        
        init(json: Object) throws {
            if let success:Object = try? json ~> "success" {
                self = try .success(T(json: success))
            } else if let message:String = try? json ~> "error" {
                self = .error(ServerError(message: message))
            } else {
                throw Errors.badResponse
            }
        }
    }
    
    enum HashChainServiceResult<T> {
        case result(T)
        case error(Error)
    }
    
    struct EmptyResponse:JsonReadable {
        init(json: Object) throws {}
    }
    
    var teamIdentity:TeamIdentity
    
    init(teamIdentity:TeamIdentity) {
        self.teamIdentity = teamIdentity
    }
    
    /**
        Create a team, thereby starting a new chain.
     */
    func createTeam(_ completionHandler:@escaping (HashChainServiceResult<UpdatedTeam>) -> Void) throws {
        
        // ensure we have an admin keypair
        guard let teamKeypair = try teamIdentity.team.getAdmin() else {
            throw Errors.needAdminKeypair
        }
        
        let createChain = HashChain.CreateChain(teamPublicKey: teamKeypair.publicKey, teamInfo: teamIdentity.team.info)
        let payload = HashChain.Payload.create(createChain)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: teamKeypair.secretKey)
        else {
            throw Errors.payloadSignature
        }
        
        // send the payload request
        let payloadDataString = try payloadData.utf8String()
        let hashChainRequest = HashChain.Request(publicKey: teamKeypair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)
        
        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(HashChainServiceResult.error(error))
                
            case .success:
                // set the block hash
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)
                var updatedTeam = self.teamIdentity.team
                updatedTeam.lastBlockHash = addedBlock.hash()
                
                HashChainBlockManager(team: updatedTeam).add(block: addedBlock)
            
                completionHandler(HashChainServiceResult.result(updatedTeam))
            }
        }

    }
    
    /** 
        Add a team member directly (without invitation).
        Requires admin keypair
     */
    func add(member:Team.MemberIdentity, _ completionHandler:@escaping (HashChainServiceResult<UpdatedTeam>) -> Void) throws {
        
        // ensure we have an admin keypair
        guard let teamKeypair = try teamIdentity.team.getAdmin() else {
            throw Errors.needAdminKeypair
        }
        
        // we need a last block hash
        guard let lastBlockhash = teamIdentity.team.lastBlockHash else {
            throw Errors.missingLastBlockHash
        }
        
        let operation = HashChain.Operation.addMember(member)
        let addMember = HashChain.AppendBlock(lastBlockHash: lastBlockhash, operation: operation)
        let payload = HashChain.Payload.append(addMember)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: teamKeypair.secretKey)
            else {
                throw Errors.payloadSignature
        }
        
        // send the payload request
        let payloadDataString = try payloadData.utf8String()
        let hashChainRequest = HashChain.Request(publicKey: teamKeypair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)

        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(HashChainServiceResult.error(error))
                
            case .success:
                // set the block hash
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)
                var updatedTeam = self.teamIdentity.team
                updatedTeam.lastBlockHash = addedBlock.hash()
                
                HashChainBlockManager(team: updatedTeam).add(block: addedBlock)
                
                completionHandler(HashChainServiceResult.result(updatedTeam))
            }
        }
    }
    
    /**
        Write an append block accepting a team invitation
        Special case: the team invitation keypair is used to sign the payload
     */
    func accept(invite:TeamInvite, _ completionHandler:@escaping (HashChainServiceResult<UpdatedTeam>) -> Void ) throws {
        
        let keyManager = try KeyManager.sharedInstance()
        let newMember = try Team.MemberIdentity(publicKey: teamIdentity.keyPair.publicKey,
                                                email: teamIdentity.email,
                                                sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                                pgpPublicKey: keyManager.loadPGPPublicKey(for: teamIdentity.email).packetData)
        
        // use the invite `seed` to create a nonce sodium keypair
        guard let nonceKeypair = try KRSodium.shared().sign.keyPair(seed: invite.seed) else {
            throw Errors.badInviteSeed
        }
        
        // get current block hash
        guard let blockHash = teamIdentity.team.lastBlockHash else {
            throw Errors.needNewestBlock
        }
        
        // create the payload
        let operation = HashChain.Operation.acceptInvite(newMember)
        let appendBlock = HashChain.AppendBlock(lastBlockHash: blockHash, operation: operation)
        let payload = HashChain.Payload.append(appendBlock)
        let payloadData = try payload.jsonData()

        // sign the payload json
        // Note: in this special case the nonce key pair is used to sign the payload
        
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: nonceKeypair.secretKey)
        else {
            throw Errors.payloadSignature
        }
        
        let payloadDataString = try payloadData.utf8String()
        let hashChainRequest = HashChain.Request(publicKey: nonceKeypair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)
        
        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(HashChainServiceResult.error(error))
                
            case .success:
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)

                var updatedTeam = self.teamIdentity.team
                updatedTeam.lastBlockHash = addedBlock.hash()
                
                HashChainBlockManager(team: updatedTeam).add(block: addedBlock)

                completionHandler(HashChainServiceResult.result(updatedTeam))
            }
        }

    }
    
    /**
        Send a ReadBlock request to the teams service as a non-member, using the invite nonce keypair
     */
    func getTeam(using invite:TeamInvite, _ completionHandler:@escaping (HashChainServiceResult<UpdatedTeam>) -> Void) throws {
        
        // use the invite `seed` to create a nonce sodium keypair
        guard let nonceKeypair = try KRSodium.shared().sign.keyPair(seed: invite.seed) else {
            throw Errors.badInviteSeed
        }
        
        let lastBlockHash = teamIdentity.team.lastBlockHash
        
        let readBlock = try HashChain.ReadBlock(teamPublicKey: invite.teamPublicKey,
                                                nonce: Data.random(size: 32),
                                                unixSeconds: UInt64(Date().timeIntervalSince1970),
                                                lastBlockHash: lastBlockHash)
        
        let payload = HashChain.Payload.read(readBlock)
        let payloadData = try payload.jsonData()
        
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: nonceKeypair.secretKey)
            else {
                throw Errors.payloadSignature
        }
        
        let hashChainRequest = try HashChain.Request(publicKey: nonceKeypair.publicKey,
                                                     payload: payloadData.utf8String(),
                                                     signature: signature)
        
        
        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<HashChain.Response>) in
            switch serverResponse {
            case .error(let error):
                completionHandler(HashChainServiceResult.error(error))
                
            case .success(let blocksResponse):
                do {
                    let updatedTeam = try blocksResponse.verifyAndDigestBlocks(for: self.teamIdentity.team)
                    
                    guard blocksResponse.hasMore else {
                        completionHandler(HashChainServiceResult.result(updatedTeam))
                        return
                    }
                    
                    self.teamIdentity.team = updatedTeam
                    try self.getTeam(using: invite, completionHandler)
                } catch {
                    completionHandler(HashChainServiceResult.error(error))
                }
            }
        }
        
    }
    
    /**
        Send a ReadBlock request to the teams service, and update the team by verifying and
        digesting any new blocks
     */
    func getVerifiedTeamUpdates(_ completionHandler:@escaping (HashChainServiceResult<UpdatedTeam>) -> Void) throws {
        
        let readBlock = try HashChain.ReadBlock(teamPublicKey: teamIdentity.team.publicKey,
                                              nonce: Data.random(size: 32),
                                              unixSeconds: UInt64(Date().timeIntervalSince1970),
                                              lastBlockHash: teamIdentity.team.lastBlockHash)
        
        let payload = HashChain.Payload.read(readBlock)
        let payloadData = try payload.jsonData()
        
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: teamIdentity.keyPair.secretKey)
        else {
            throw Errors.payloadSignature
        }
        
        
        let hashChainRequest = try HashChain.Request(publicKey: teamIdentity.keyPair.publicKey,
                                                     payload: payloadData.utf8String(),
                                                     signature: signature)
        
        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<HashChain.Response>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(HashChainServiceResult.error(error))
                
            case .success(let blocksResponse):
                do {
                    
                    let updatedTeam = try blocksResponse.verifyAndDigestBlocks(for: self.teamIdentity.team)
                    
                    guard blocksResponse.hasMore else {
                        completionHandler(HashChainServiceResult.result(updatedTeam))
                        return
                    }
                    
                    self.teamIdentity.team = updatedTeam
                    try self.getVerifiedTeamUpdates(completionHandler)
                } catch {
                    completionHandler(HashChainServiceResult.error(error))
                }
            }
        }
        
    }
    
    /**
        Check that the `block` succesfully posted to the chain
     */
    func check(posted block:HashChain.Block, _ completionHandler:@escaping (HashChainServiceResult<Bool>) -> Void) throws {
        try getVerifiedTeamUpdates({ (response) in
            switch response {
            case .error(let e):
                completionHandler(HashChainServiceResult.error(e))
            case .result:
                let hasBlock = (try? HashChainBlockManager(team: self.teamIdentity.team).fetchBlock(hash: block.hash().toBase64())) != nil
                
                completionHandler(HashChainServiceResult.result(hasBlock))
            }
        })
    }
    
    /** 
        Send a JSON object to the teams service and parse the response as a ServerResponse
     */
    func sendRequest<T:JsonReadable>(object:Object, _ onCompletion:@escaping (ServerResponse<T>) -> Void) throws {
        let req = try HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object, requestSerializer: JSONParameterSerializer())
        
        log("HashChain - IN:\n\(object)", .warning)

        req.start { response in
            do {
                let json:Object = try JSON.parse(data: response.data)
                log("HashChain - OUT:\n\(json)", .warning)
                
                let serverResponse = try ServerResponse<T>(json: json)
                onCompletion(serverResponse)
            } catch {
                
                onCompletion(ServerResponse.error(ServerError(message: "Unexpected response. \(error)")))
            }
        }
    }
}
