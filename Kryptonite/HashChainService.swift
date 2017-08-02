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
    
    struct ServerError:Error {
        let message:String
    }
    
    enum Errors:Error {
        case badResponse
        case badInviteSeed
        
        case payloadSignature
        case needNewestBlock
        
        case errorResponse(ServerError)
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
    
    let teamIdentity:TeamIdentity
    
    init(teamIdentity:TeamIdentity) {
        self.teamIdentity = teamIdentity
    }
    
    /**
        Write an append block accepting a team invitation
        Special case: the team invitation keypair is used to sign the payload
     */
    func accept(invite:TeamInvite, _ completionHandler:@escaping (HashChainServiceResult<HashChain.Block>) -> Void ) throws {
        
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
        guard let blockHash = try teamIdentity.team.getLastBlockHash() else {
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
        let hashChainRequest = HashChain.Request(publicKey: teamIdentity.keyPair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)
        
        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(HashChainServiceResult.error(error))
                
            case .success:
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)                
                completionHandler(HashChainServiceResult.result(addedBlock))
            }
        }

    }
    
    /**
        Send a ReadBlock request to the teams service, and update the team by verifying and
        digesting any new blocks
     */
    func getVerifiedTeamUpdates(_ completionHandler:@escaping (HashChainServiceResult<Team>) -> Void) throws {
        
        let readBlock = try HashChain.ReadBlock(teamPublicKey: teamIdentity.team.publicKey,
                                              nonce: Data.random(size: 32),
                                              unixSeconds: UInt64(Date().timeIntervalSince1970),
                                              lastBlockHash: teamIdentity.team.getLastBlockHash())
        
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
                    completionHandler(HashChainServiceResult.result(updatedTeam))
                } catch {
                    completionHandler(HashChainServiceResult.error(error))
                }
            }
        }
        
    }
    
    /** 
        Send a JSON object to the teams service and parse the response as a ServerResponse
     */
    func sendRequest<T:JsonReadable>(object:Object, _ onCompletion:@escaping (ServerResponse<T>) -> Void) throws {
        let req = try HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object)
        req.start { response in
            do {
                let serverResponse = try ServerResponse<T>(jsonData: response.data)
                onCompletion(serverResponse)
            } catch {
                onCompletion(ServerResponse.error(ServerError(message: "Unexpected response. \(error)")))
            }
        }

    }
}
