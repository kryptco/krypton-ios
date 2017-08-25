//
//  TeamService.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/1/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import SwiftHTTP

class TeamService {
    
    // static instance
    static var instance:TeamService? = nil
    static let mutex = Mutex()
    
    class func shared() throws -> TeamService {
        defer { mutex.unlock() }
        mutex.lock()
        
        guard let teamIdentity = try IdentityManager.getTeamIdentity() else {
            throw Errors.noTeam
        }
        
        guard let i = instance else {
            instance = TeamService(teamIdentity: teamIdentity, mutex: mutex)
            return instance!
        }
        
        i.teamIdentity = teamIdentity
        
        return i
    }
    
    class func temporary(for teamIdentity:TeamIdentity) -> TeamService {
        return TeamService(teamIdentity: teamIdentity, mutex: Mutex())
    }

    
    enum Errors:Error {
        case noTeam
        
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
            return "Server responded with: \(message)."
        }
    }
    
    enum ServerResponse<T:JsonReadable>:JsonReadable, CustomDebugStringConvertible {
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
        
        var debugDescription: String {
            switch self {
            case .success(let obj):
                return "SUCCESS \n\t-\(obj)"
            case .error(let error):
                return "FAILURE \n\t-\(error)"
            }
        }
    }
    
    enum TeamServiceResult<T> {
        case result(T)
        case error(Error)
    }
    
    struct EmptyResponse:JsonReadable {
        init(json: Object) throws {}
    }
    
    var teamIdentity:TeamIdentity
    var mutex:Mutex
    
    private init(teamIdentity:TeamIdentity, mutex:Mutex) {
        self.teamIdentity = teamIdentity
        self.mutex = mutex
    }
    
    /**
        Create a team and add the admin, thereby starting a new chain 
        with the admin as the first team member
     */
    func createTeam(_ completionHandler:@escaping (TeamServiceResult<(TeamService)>) -> Void) throws {
        mutex.lock()
        
        // ensure we have an admin keypair
        guard let teamKeypair = try teamIdentity.team.adminKeyPair() else {
            mutex.unlock()
            throw Errors.needAdminKeypair
        }
        
        let createChain = HashChain.CreateChain(teamPublicKey: teamKeypair.publicKey, teamInfo: teamIdentity.team.info)
        let payload = HashChain.Payload.create(createChain)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: teamKeypair.secretKey)
        else {
            mutex.unlock()
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
                completionHandler(TeamServiceResult.error(error))
                self.mutex.unlock()
                
            case .success:
                // set the block hash
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)
                
                self.teamIdentity.team.lastBlockHash = addedBlock.hash()
                self.teamIdentity.dataManager.add(block: addedBlock)
                
                completionHandler(TeamServiceResult.result(self))
                self.mutex.unlock()
            }
        }

    }
    
    /** 
        Add a team member directly (without invitation).
        Requires admin keypair
     */
    func add(member:Team.MemberIdentity, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        mutex.lock()
        
        // ensure we have an admin keypair
        guard let teamKeypair = try teamIdentity.team.adminKeyPair() else {
            mutex.unlock()
            throw Errors.needAdminKeypair
        }
        
        // we need a last block hash
        guard let lastBlockhash = teamIdentity.team.lastBlockHash else {
            mutex.unlock()
            throw Errors.missingLastBlockHash
        }
        
        let operation = HashChain.Operation.addMember(member)
        let addMember = HashChain.AppendBlock(lastBlockHash: lastBlockhash, operation: operation)
        let payload = HashChain.Payload.append(addMember)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: teamKeypair.secretKey)
            else {
                mutex.unlock()
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
                completionHandler(TeamServiceResult.error(error))
                self.mutex.unlock()
                
            case .success:
                // set the block hash
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)
                
                let blockHash = addedBlock.hash()
                self.teamIdentity.team.lastBlockHash = addedBlock.hash()
                self.teamIdentity.dataManager.add(block: addedBlock)
                self.teamIdentity.dataManager.add(member: member, blockHash: blockHash)

                completionHandler(TeamServiceResult.result(self))
                self.mutex.unlock()

            }
        }
    }
    
    /**
        Write an append block accepting a team invitation
        Special case: the team invitation keypair is used to sign the payload
     */
    func accept(invite:TeamInvite, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void ) throws {
        mutex.lock()
        
        let keyManager = try KeyManager.sharedInstance()
        let newMember = try Team.MemberIdentity(publicKey: teamIdentity.keyPair.publicKey,
                                                email: teamIdentity.email,
                                                sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                                pgpPublicKey: keyManager.loadPGPPublicKey(for: teamIdentity.email).packetData)
        
        // use the invite `seed` to create a nonce sodium keypair
        guard let nonceKeypair = try KRSodium.shared().sign.keyPair(seed: invite.seed) else {
            mutex.unlock()
            throw Errors.badInviteSeed
        }
        
        // get current block hash
        guard let blockHash = teamIdentity.team.lastBlockHash else {
            mutex.unlock()
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
            mutex.unlock()
            throw Errors.payloadSignature
        }
        
        let payloadDataString = try payloadData.utf8String()
        let hashChainRequest = HashChain.Request(publicKey: nonceKeypair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)
        
        try sendRequest(object: hashChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                self.mutex.unlock()
                
            case .success:
                let addedBlock = HashChain.Block(payload: payloadDataString, signature: signature)
                let blockHash = addedBlock.hash()
                self.teamIdentity.team.lastBlockHash = blockHash
                self.teamIdentity.dataManager.add(block: addedBlock)
                self.teamIdentity.dataManager.add(member: newMember, blockHash: blockHash)

                completionHandler(TeamServiceResult.result(self))
                self.mutex.unlock()
            }
        }

    }
    
    /**
        Send a ReadBlock request to the teams service as a non-member, using the invite nonce keypair
     */
    func getTeam(using invite:TeamInvite, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        
        mutex.lock()
        
        do {
            try getTeamUnlocked(using: invite) { result in
                completionHandler(result)
                self.mutex.unlock()
            }
        } catch {
            mutex.unlock()
            throw error
        }
    }
    
    private func getTeamUnlocked(using invite:TeamInvite, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        
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
                completionHandler(TeamServiceResult.error(error))
                
            case .success(let blocksResponse):
                do {
                    let updatedTeam = try blocksResponse.verifyAndProcessBlocks(team: self.teamIdentity.team, dataManager: self.teamIdentity.dataManager)
                    
                    self.teamIdentity.team = updatedTeam

                    guard blocksResponse.hasMore else {
                        completionHandler(TeamServiceResult.result(self))
                        return
                    }
                    
                    try self.getTeamUnlocked(using: invite, completionHandler)
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                }
            }
        }
        
    }

    
    /**
        Send a ReadBlock request to the teams service, and update the team by verifying and
        digesting any new blocks
     */
    func getVerifiedTeamUpdates(_ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        mutex.lock()
        
        do {
            try getVerifiedTeamUpdatesUnlocked() { result in
                completionHandler(result)
                self.mutex.unlock()
            }
        } catch {
            mutex.unlock()
            throw error
        }
    }
    
    private func getVerifiedTeamUpdatesUnlocked(_ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        
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
                completionHandler(TeamServiceResult.error(error))
                
            case .success(let blocksResponse):
                do {
                    
                    let updatedTeam = try blocksResponse.verifyAndProcessBlocks(team: self.teamIdentity.team, dataManager: self.teamIdentity.dataManager)
                    
                    self.teamIdentity.team = updatedTeam

                    guard blocksResponse.hasMore else {
                        completionHandler(TeamServiceResult.result(self))
                        return
                    }
                    
                    try self.getVerifiedTeamUpdates(completionHandler)
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                }
            }
        }
        
    }
    
    
    /** 
        Send a JSON object to the teams service and parse the response as a ServerResponse
     */
    func sendRequest<T:JsonReadable>(object:Object, _ onCompletion:@escaping (ServerResponse<T>) -> Void) throws {
        let req = try HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object, requestSerializer: JSONParameterSerializer())
        
        log("[IN] HashChainSVC\n\t\(object)")

        req.start { response in
            do {
                let serverResponse = try ServerResponse<T>(jsonData: response.data)
                log("[OUT] HashChainSVC\n\t\(serverResponse)")

                onCompletion(serverResponse)
            } catch {
                let responseString = (try? response.data.utf8String()) ?? "\(response.data.count) bytes"
                onCompletion(ServerResponse.error(ServerError(message: "unexpected response, \(responseString)")))
            }
        }
    }
}
