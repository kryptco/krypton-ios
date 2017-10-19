//
//  MemoryTeamServer.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/15/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//


import Foundation
@testable import Kryptonite

import SwiftHTTP
import JSON

class MemoryTeamServerHTTP:TeamServiceAPI {
    
    let server:MemoryTeamServer
    init() {
        self.server = MemoryTeamServer()
    }
    
    /**
        A local Memory team server interface to talk to the MemoryTeamServer
     */
    func sendRequest<T>(object:Object, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void) {
        do {
            let response:TeamService.ServerResponse<T> = try server.sendRequest(object: object)
            onCompletion(response)
        } catch {
            onCompletion(TeamService.ServerResponse.error(TeamService.ServerError(message: "\(error)")))
        }
    }
    
    func sendRequestSynchronously<T>(object: Object) -> TeamService.ServerResponse<T> where T : JsonReadable {
        do {
            let response:TeamService.ServerResponse<T> = try server.sendRequest(object: object)
            return response
        } catch {
            return TeamService.ServerResponse.error(TeamService.ServerError(message: "\(error)"))
        }
    }

}

class MemoryTeamServer {
    
    enum Errors:Error {
        case teamChainDoesNotExist
        case badSignature
        case badReadBlockSignature
        
        case chainAlreadyExists
        
        case invalidRequestPublicKey
        case invalidAppendBlockSignerPublicKey
        
        case unexpectedServerResponseType
        
        case wrongBlockTypeInternal
    }
    
    let mutex = Mutex()
    var teamChainLookup:[Data:TeamChain] = [:]

    /** Set & Lookup for Team Chains */
    func point(teamChain:TeamChain, to pointer:Data) {
        teamChainLookup[pointer] = teamChain
    }
    
    
    func chain(for pointer:Data) -> TeamChain? {
        return teamChainLookup[pointer]
    }
    
    
    /** Team Data Chain **/
    class TeamChain {
        var teamIdentity:TeamIdentity
        let mutex = Mutex()
        
        var logChains:[LogChain] = []
        var logChainLookup:[Data:LogChain] = [:]

        init(teamIdentity:TeamIdentity) {
            self.teamIdentity = teamIdentity
        }
        
        /** Set & Lookup Log Chains */
        func point(teamChain:LogChain, to pointer:Data) {
            logChainLookup[pointer] = teamChain
        }

        func chain(for pointer:Data) -> LogChain? {
            return logChainLookup[pointer]
        }
        
        
        // read blocks
        func read(block: SigChain.Block) throws -> [SigChain.Block] {
            defer { mutex.unlock() }
            mutex.lock()
            
            // ensure it's a read block
            guard case .readBlocks(let read) = try SigChain.Payload(jsonString: block.payload) else {
                throw Errors.wrongBlockTypeInternal
            }
            
            // ensure the public key is a member's public key or an invitation public key
            var publicKey:SodiumSignPublicKey
            if let invitationNoncePublicKey = try self.teamIdentity.team().lastInvitePublicKey, invitationNoncePublicKey == block.publicKey {
                publicKey = invitationNoncePublicKey
            } else {
                guard try teamIdentity.dataManager.isAdmin(for: block.publicKey) else {
                    throw Errors.invalidAppendBlockSignerPublicKey
                }
                
                publicKey = block.publicKey
            }
            
            // verify the read block signature
            guard try KRSodium.instance().sign.verify(message: block.payload.utf8Data(), publicKey: publicKey, signature: block.signature) else {
                throw Errors.badSignature
            }
            
            var blocks:[SigChain.Block]
            switch read.teamPointer {
            case .publicKey:
                blocks = try teamIdentity.dataManager.fetchAll()
            case .lastBlockHash(let hash):
                blocks = try teamIdentity.dataManager.fetchBlocks(after: hash)
            }
            
            return blocks
        }
        
        // apend a block
        func append(block:SigChain.Block) throws {
            defer { mutex.unlock() }
            mutex.lock()
            
            try self.teamIdentity.verifyAndProcessBlocks(response: SigChain.Response(blocks: [block], hasMore: false))
        }
        
        class LogChain {
            
        }
    }
    
    func sendRequest<T:JsonReadable>(object:Object) throws -> TeamService.ServerResponse<T> {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request = try SigChain.Request(json: object)
        let block = SigChain.Block(publicKey: request.publicKey, payload: request.payload, signature: request.signature)
        
        // get the payload
        let payload = try SigChain.Payload(jsonString: request.payload)
        switch payload {
        case .readBlocks(let read):
            guard let teamChain:TeamChain = chain(for: read.teamPointer.pointer) else {
                throw Errors.teamChainDoesNotExist
            }
            
            let blocks = try teamChain.read(block: block)
            
            // hash blocks response
            let response = SigChain.Response(blocks: blocks, hasMore: false)
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)
            
            
        case .appendBlock(let append):
            guard let teamChain:TeamChain = chain(for: append.lastBlockHash) else {
                throw Errors.teamChainDoesNotExist
            }
            
            try teamChain.append(block: block)
            
            point(teamChain: teamChain, to: block.hash())
            
            // empty response
            let response = TeamService.EmptyResponse()
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)
            
        case .createChain(let create):
            guard chain(for: create.creator.publicKey) == nil else {
                throw Errors.chainAlreadyExists
            }
            
            // verify signature
            guard try KRSodium.instance().sign.verify(message: request.payload.utf8Data(), publicKey: request.publicKey, signature: request.signature) else {
                throw Errors.badSignature
            }
            
            // verify self-signed create
            guard request.publicKey == create.creator.publicKey else {
                throw Errors.invalidRequestPublicKey
            }
            
            let teamIdentity = try TeamIdentity.newMember(email: "server", checkpoint: block.hash(), initialTeamPublicKey: create.creator.publicKey)
            let teamChain = TeamChain(teamIdentity: teamIdentity)
            
            point(teamChain: teamChain, to: create.creator.publicKey)
            point(teamChain: teamChain, to: block.hash())
            
            // empty response
            let response = TeamService.EmptyResponse()
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)
        
        case .createLogChain( _):
            let response = TeamService.EmptyResponse()
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)

            
        case .readLogBlocks( _):
            let response = TeamService.EmptyResponse()
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)

            
        case .appendLogBlock(_):
            let response = TeamService.EmptyResponse()
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)

        }
    }
    

}

extension SigChain.TeamPointer {
    
    var pointer:Data {
        switch self {
        case .publicKey(let pub):
            return pub
        case .lastBlockHash(let hash):
            return hash
        }
    }
}
