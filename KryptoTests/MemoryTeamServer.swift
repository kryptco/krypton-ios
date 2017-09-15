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
    func sendRequest<T:JsonReadable>(object:Object, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void) throws {
        let response:TeamService.ServerResponse<T> = try server.sendRequest(object: object)
        onCompletion(response)
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
    
    func point(teamChain:TeamChain, to pointer:Data) {
        teamChainLookup[pointer] = teamChain
    }
    
    func chain(for pointer:Data) -> TeamChain? {
        return teamChainLookup[pointer]
    }
    
    class TeamChain {
        var teamIdentity:TeamIdentity
        let mutex = Mutex()
        
        init(teamIdentity:TeamIdentity) {
            self.teamIdentity = teamIdentity
        }
        
        func read(block: HashChain.Block) throws -> [HashChain.Block] {
            defer { mutex.unlock() }
            mutex.lock()
            
            // ensure it's a read block
            guard case .read(let read) = try HashChain.Payload(jsonString: block.payload) else {
                throw Errors.wrongBlockTypeInternal
            }
            
            // ensure the public key is a member's public key or an invitation public key
            var publicKey:SodiumPublicKey
            if let invitationNoncePublicKey = self.teamIdentity.team.lastInvitePublicKey, invitationNoncePublicKey == block.publicKey {
                publicKey = invitationNoncePublicKey
            } else {
                guard try teamIdentity.dataManager.isAdmin(for: block.publicKey) else {
                    throw Errors.invalidAppendBlockSignerPublicKey
                }
                
                publicKey = block.publicKey
            }
            
            // verify the read block signature
            guard try KRSodium.shared().sign.verify(message: block.payload.utf8Data(), publicKey: publicKey, signature: block.signature) else {
                throw Errors.badSignature
            }
            
            var blocks:[HashChain.Block]
            switch read.teamPointer {
            case .publicKey:
                blocks = try teamIdentity.dataManager.fetchAll()
            case .lastBlockHash(let hash):
                blocks = try teamIdentity.dataManager.fetchBlocks(after: hash)
            }
            
            return blocks
        }
        
        func append(block:HashChain.Block) throws {
            defer { mutex.unlock() }
            mutex.lock()
            
            try self.teamIdentity.verifyAndProcessBlocks(response: HashChain.Response(blocks: [block], hasMore: false))
        }
    }
    
    func sendRequest<T:JsonReadable>(object:Object) throws -> TeamService.ServerResponse<T> {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request = try HashChain.Request(json: object)
        let block = HashChain.Block(publicKey: request.publicKey, payload: request.payload, signature: request.signature)
        
        // get the payload
        let payload = try HashChain.Payload(jsonString: request.payload)
        switch payload {
        case .read(let read):
            guard let teamChain = chain(for: read.teamPointer.pointer) else {
                throw Errors.teamChainDoesNotExist
            }
            
            let blocks = try teamChain.read(block: block)
            
            // hash blocks response
            let response = HashChain.Response(blocks: blocks, hasMore: false)
            
            guard let responseType = response as? T else {
                throw Errors.unexpectedServerResponseType
            }
            
            return  TeamService.ServerResponse.success(responseType)
            
            
        case .append(let append):
            guard let teamChain = chain(for: append.lastBlockHash) else {
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
            
        case .create(let create):
            guard chain(for: create.creator.publicKey) == nil else {
                throw Errors.chainAlreadyExists
            }
            
            // verify signature
            guard try KRSodium.shared().sign.verify(message: request.payload.utf8Data(), publicKey: request.publicKey, signature: request.signature) else {
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
        }
    }
}

extension HashChain.TeamPointer {
    
    var pointer:Data {
        switch self {
        case .publicKey(let pub):
            return pub
        case .lastBlockHash(let hash):
            return hash
        }
    }
}
