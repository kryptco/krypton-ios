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

protocol TeamServiceAPI {
    func sendRequest<T>(object:Object, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void)
    func sendRequestSynchronously<T>(object:Object) -> TeamService.ServerResponse<T>
}

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
    
    class func temporary(for teamIdentity:TeamIdentity, server:TeamServiceAPI = TeamServerHTTP()) -> TeamService {
        return TeamService(teamIdentity: teamIdentity, mutex: Mutex(), server: server)
    }

    
    enum Errors:Error {
        case noTeam
        
        case badResponse
        case badInviteSeed
        
        case payloadSignature
        case needNewestBlock
        case checkpointNotReached
        
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
                return "SUCCESS:\n\t\t- \(obj)"
            case .error(let error):
                return "FAILURE:\n\t\t- \(error)"
            }
        }
    }
    
    enum TeamServiceResult<T> {
        case result(T)
        case error(Error)
    }
    
    struct EmptyResponse:JsonReadable {
        init() {}
        init(json: Object) throws {}
    }

    var teamIdentity:TeamIdentity
    var mutex:Mutex
    var server:TeamServiceAPI
    
    private init(teamIdentity:TeamIdentity, mutex:Mutex, server:TeamServiceAPI = TeamServerHTTP()) {
        self.teamIdentity = teamIdentity
        self.mutex = mutex
        self.server = server
    }
    
    /**
        Create a team and add the admin, thereby starting a new chain 
        with the admin as the first team member
     */
    func createTeam(createBlock:SigChain.Block, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        mutex.lock()
        
        // send the payload request
        let sigChainRequest = SigChain.Request(publicKey: createBlock.publicKey,
                                                 payload: createBlock.payload,
                                                 signature: createBlock.signature)

        server.sendRequest(object: sigChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            defer { self.mutex.unlock() }
            
            switch serverResponse {
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))

            case .success:
                completionHandler(TeamServiceResult.result(self))
            }
        }
    }
    
    /** 
        Add a team member directly (without invitation).
        Requires admin keypair
     */
    func add(member:Team.MemberIdentity, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        mutex.lock()
        
        // we need a last block hash
        guard let lastBlockhash = try teamIdentity.lastBlockHash() else {
            mutex.unlock()
            throw Errors.missingLastBlockHash
        }
        
        let operation = SigChain.Operation.addMember(member)
        let addMember = SigChain.AppendBlock(lastBlockHash: lastBlockhash, operation: operation)
        let payload = SigChain.Payload.appendBlock(addMember)
        let payloadData = try payload.jsonData()
        
        // sign the payload
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: teamIdentity.keyPair.secretKey)
            else {
                mutex.unlock()
                throw Errors.payloadSignature
        }
        
        // send the payload request
        let payloadDataString = try payloadData.utf8String()
        let sigChainRequest = SigChain.Request(publicKey: teamIdentity.keyPair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)

        server.sendRequest(object: sigChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                self.mutex.unlock()
                
            case .success:
                // set the block hash
                let addedBlock = SigChain.Block(publicKey: self.teamIdentity.keyPair.publicKey, payload: payloadDataString, signature: signature)
                
                do {
                    try self.teamIdentity.dataManager.add(member: member, block: addedBlock)
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                    self.mutex.unlock()
                    return
                }
                
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
                                                encryptionPublicKey: teamIdentity.encryptionKeyPair.publicKey,
                                                email: teamIdentity.email,
                                                sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                                pgpPublicKey: keyManager.loadPGPPublicKey(for: teamIdentity.email).packetData)
        
        // use the invite `seed` to create a nonce sodium keypair
        guard let nonceKeypair = KRSodium.instance().sign.keyPair(seed: invite.seed) else {
            mutex.unlock()
            throw Errors.badInviteSeed
        }
        
        // get current block hash
        guard let blockHash = try teamIdentity.lastBlockHash() else {
            mutex.unlock()
            throw Errors.needNewestBlock
        }
        
        // create the payload
        let operation = SigChain.Operation.acceptInvite(newMember)
        let appendBlock = SigChain.AppendBlock(lastBlockHash: blockHash, operation: operation)
        let payload = SigChain.Payload.appendBlock(appendBlock)
        let payloadData = try payload.jsonData()

        // sign the payload json
        // Note: in this special case the nonce key pair is used to sign the payload
        
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: nonceKeypair.secretKey)
        else {
            mutex.unlock()
            throw Errors.payloadSignature
        }
        
        let payloadDataString = try payloadData.utf8String()
        let sigChainRequest = SigChain.Request(publicKey: nonceKeypair.publicKey,
                                                 payload: payloadDataString,
                                                 signature: signature)
        
        server.sendRequest(object: sigChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                self.mutex.unlock()
                
            case .success:
                let addedBlock = SigChain.Block(publicKey: nonceKeypair.publicKey, payload: payloadDataString, signature: signature)
                                
                do {
                    try self.teamIdentity.dataManager.add(member: newMember, block: addedBlock)
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                    self.mutex.unlock()
                    return
                }
                
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
        guard let nonceKeypair = KRSodium.instance().sign.keyPair(seed: invite.seed) else {
            throw Errors.badInviteSeed
        }
        
        let readBlock = try SigChain.ReadBlocks(teamPointer: invite.teamPointer,
                                                nonce: Data.random(size: 32),
                                                unixSeconds: UInt64(Date().timeIntervalSince1970))
        
        let payload = SigChain.Payload.readBlocks(readBlock)
        let payloadData = try payload.jsonData()
        
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: nonceKeypair.secretKey)
            else {
                throw Errors.payloadSignature
        }
        
        let sigChainRequest = try SigChain.Request(publicKey: nonceKeypair.publicKey,
                                                     payload: payloadData.utf8String(),
                                                     signature: signature)
        
        
        server.sendRequest(object: sigChainRequest.object) { (serverResponse:ServerResponse<SigChain.Response>) in
            switch serverResponse {
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success(let response):
                do {
                    guard response.hasBlocks else {
                        
                        guard try self.teamIdentity.isCheckPointReached() else {
                            completionHandler(TeamServiceResult.error(Errors.checkpointNotReached))
                            return
                        }
                        
                        completionHandler(TeamServiceResult.result(self))
                        return
                    }
                    
                    // verify and append incoming blocks
                    try self.teamIdentity.verifyAndProcessBlocks(response: response)
                    
                    guard response.hasMore else {
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
        
        let readBlock = try SigChain.ReadBlocks(teamPointer: teamIdentity.teamPointer(),
                                              nonce: Data.random(size: 32),
                                              unixSeconds: UInt64(Date().timeIntervalSince1970))
        
        let payload = SigChain.Payload.readBlocks(readBlock)
        let payloadData = try payload.jsonData()
        
        guard let signature = KRSodium.instance().sign.signature(message: payloadData, secretKey: teamIdentity.keyPair.secretKey)
        else {
            throw Errors.payloadSignature
        }
        
        
        let sigChainRequest = try SigChain.Request(publicKey: teamIdentity.keyPair.publicKey,
                                                     payload: payloadData.utf8String(),
                                                     signature: signature)
        
        server.sendRequest(object: sigChainRequest.object) { (serverResponse:ServerResponse<SigChain.Response>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success(let response):
                do {
                    guard response.hasBlocks else {
                        
                        
                        guard try self.teamIdentity.isCheckPointReached() else {
                            completionHandler(TeamServiceResult.error(Errors.checkpointNotReached))
                            return
                        }

                        completionHandler(TeamServiceResult.result(self))
                        return
                    }
                    
                    // verify and append incoming blocks
                    try self.teamIdentity.verifyAndProcessBlocks(response: response)

                    guard response.hasMore else {
                        completionHandler(TeamServiceResult.result(self))
                        return
                    }
                    
                    try self.getVerifiedTeamUpdatesUnlocked(completionHandler)
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                }
            }
        }
        
    }
    
    /**
         Send Encrypted Audit Logs
     */
    func sendUnsentLogBlocks(_ completionHandler:@escaping (TeamServiceResult<Bool>) -> Void) throws {
        mutex.lock()
        
        do {
            let logBlocks:Array<SigChain.LogBlock> = try self.teamIdentity.dataManager.fetchUnsentLogBlocks().reversed()
            
            try sendUnsentLogBlocksUnlocked(logBlocks: logBlocks) { result in
                completionHandler(result)
                self.mutex.unlock()
            }
        } catch {
            mutex.unlock()
            throw error
        }
    }
    
    private func sendUnsentLogBlocksUnlocked(logBlocks:[SigChain.LogBlock], _ completionHandler:@escaping (TeamServiceResult<Bool>) -> Void) throws {
        
        var remainingLogBlocks = logBlocks
        
        guard let logBlock = remainingLogBlocks.popLast() else {
            completionHandler(TeamServiceResult.result(true))
            return
        }
        
        let sigChainRequest = SigChain.Request(publicKey: teamIdentity.keyPair.publicKey,
                                                     payload: logBlock.payload,
                                                     signature: logBlock.signature)
        
        server.sendRequest(object: sigChainRequest.object) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success:
                do {
                    try self.teamIdentity.dataManager.markLogBlocksSent(logBlocks: [logBlock])
                    
                    guard remainingLogBlocks.isEmpty else {
                        try self.sendUnsentLogBlocksUnlocked(logBlocks: remainingLogBlocks, completionHandler)
                        return
                    }
                    
                    completionHandler(TeamServiceResult.result(true))
                    
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                }
                
            }
        }
    }
    
    // Fufill Team Operation Requests
    func responseFor(requestableOperation:RequestableTeamOperation) throws -> (TeamService, TeamOperationResponse)
    {
        mutex.lock()
        defer { mutex.unlock() }
        
        //TODO: Handle not up to date blocks
        struct UnimplementedError:Error {}
        
        var teamOperationResponse:TeamOperationResponse
        var request:SigChain.Request

        switch requestableOperation {
        case .invite:
            let (inviteLink, sigChainRequest) = try teamIdentity.invitationBlock()
            
            request = sigChainRequest
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash(),
                                                          data: TeamOperationResponseData.inviteLink(inviteLink))
        case .cancelInvite:
            request = try teamIdentity.cancelInvitationBlock()
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .removeMember(let memberPublicKey):
            request = try teamIdentity.removeMemberBlock(for: memberPublicKey)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .setPolicy(let policy):
            request = try teamIdentity.setPolicyBlock(for: policy)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .setTeamInfo(let info):
            request = try teamIdentity.setTeamInfoBlock(for: info)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .pinHostKey(let hostKey):
            request = try teamIdentity.pinHostKeyBlock(for: hostKey)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .unpinHostKey(let hostKey):
            request = try teamIdentity.unpinHostKeyBlock(for: hostKey)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .addLoggingEndpoint(let endpoint):
            request = try teamIdentity.addLoggingEndpoingBlock(for: endpoint)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .removeLoggingEndpoint(let endpoint):
            request = try teamIdentity.removeLoggingEndpoingBlock(for: endpoint)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .addAdmin(let memberPublicKey):
            request = try teamIdentity.addAdminBlock(for: memberPublicKey)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())

        case .removeAdmin(let adminPublicKey):
            request = try teamIdentity.removeAdminBlock(for: adminPublicKey)
            teamOperationResponse = TeamOperationResponse(postedBlockHash: request.block.hash())
        }
        
        let response:ServerResponse<EmptyResponse> = server.sendRequestSynchronously(object: request.object)
        
        switch response {
        case .error(let error):
            throw error
        case .success:
            break
        }
        
        // process the new block we just created and posted
        try self.teamIdentity.verifyAndProcessBlocks(response: SigChain.Response(blocks: [request.block], hasMore: false))
        
        // return an `ok` with the team operation response
        return (self, teamOperationResponse)
    }
}

/// TeamIdentity + TeamPointer
extension TeamIdentity {
    func teamPointer() throws -> SigChain.TeamPointer {
        if let blockHash = try self.lastBlockHash() {
            return SigChain.TeamPointer.lastBlockHash(blockHash)
        }
        
        return SigChain.TeamPointer.publicKey(self.initialTeamPublicKey)
    }
}


/// TeamInvite + TeamPointer
extension TeamInvite {
    var teamPointer:SigChain.TeamPointer {
        return SigChain.TeamPointer.publicKey(self.initialTeamPublicKey)
    }
}



