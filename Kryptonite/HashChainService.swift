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
        case payloadSignature
        case errorResponse(ServerError)
    }
    
    enum ServerResponse:JsonReadable {
        case error(ServerError)
        case success(HashChain.Response)
        
        init(json: Object) throws {
            if let success:Object = try? json ~> "success" {
                self = try .success(HashChain.Response(json: success))
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
    
    
    let teamIdentity:TeamIdentity
    
    init(teamIdentity:TeamIdentity) {
        self.teamIdentity = teamIdentity
    }
    
    /**
        Send a ReadBlock request to the teams service, and update the team by verifying and
        digesting any new blocks
     */
    func getVerifiedTeamUpdates(_ completionHandler:@escaping (HashChainServiceResult<Team>) -> Void ) throws {
        
        let payload = try HashChain.ReadBlock(teamPublicKey: teamIdentity.team.publicKey,
                                              nonce: Data.random(size: 32),
                                              unixSeconds: UInt64(Date().timeIntervalSince1970),
                                              lastBlockHash: teamIdentity.team.getLastBlockHash())
        
        let payloadData = try payload.jsonData()
        
        guard let signature = try KRSodium.shared().sign.signature(message: payloadData, secretKey: teamIdentity.keyPair.secretKey)
        else {
            throw Errors.payloadSignature
        }
        
        
        let hashChainRequest = try HashChain.Request(publicKey: teamIdentity.keyPair.publicKey,
                                                     payload: payloadData.utf8String(),
                                                     signature: signature)
        
        try sendRequest(object: hashChainRequest.object) { serverResponse in
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
    func sendRequest(object:Object, _ onCompletion:@escaping (ServerResponse) -> Void) throws {
        let req = try HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object)
        req.start { response in
            do {
                let serverResponse = try ServerResponse(jsonData: response.data)
                onCompletion(serverResponse)
            } catch {
                onCompletion(ServerResponse.error(ServerError(message: "Unexpected response. \(error)")))
            }
        }

    }
}
