//
//  LocalU2FRequest.swift
//  Krypton
//
//  Created by Alex Grinman on 8/6/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct LocalU2FRequest {
    let type:RequestType
    let appId:String
    let challenge:Data
    let registeredKeys:[RegisteredKeys]?
    
    let timeoutSeconds:Double?
    let requestId:Double?
    let displayIdentifier:String?
    
    enum Errors:Error {
        case unknownRequestType
        case noKnownKeyHandle
    }
    
    enum RequestType:String {
        case register = "u2f_register_request"
        case sign = "u2f_sign_request"
    }
    
    struct RegisteredKeys {
        let keyHandle:Data
    }
    
    func toRequest() throws -> Request {
        
        var body:RequestBody
        switch type {
        case .register:
            body = .u2fRegister(U2FRegisterRequest(challenge: challenge, appID: appId))
        case .sign:
            // find the associated keyHandle
            
            var matchingKeyHandle:U2FKeyHandle?
            
            for key in self.registeredKeys ?? [] {
                do {
                    try key.keyHandle.validate(for: appId)
                    matchingKeyHandle = key.keyHandle
                    break
                } catch {
                    continue
                }
            }
            guard let keyHandle = matchingKeyHandle else {
                throw Errors.noKnownKeyHandle
            }
            
            body = .u2fAuthenticate(U2FAuthenticateRequest(challenge: challenge, keyHandle: keyHandle, appID: appId))
        }
        
        return Request(id: try Data.random(size: 32).toBase64(),
                       unixSeconds: Int(Date().timeIntervalSince1970),
                       sendACK: false,
                       version: Properties.currentVersion,
                       body: body)
    }
}

extension LocalU2FRequest.RegisteredKeys:JsonReadable {
    init(json: Object) throws {
        keyHandle = try ((json ~> "keyHandle") as String).fromBase64()
    }
}

extension LocalU2FRequest:JsonReadable {
    init(json: Object) throws {
        guard let requestType = try RequestType(rawValue: json ~> "type") else {
            throw Errors.unknownRequestType
        }
        
        type = requestType
        appId = try json ~> "appId"
        challenge = try ((json ~> "challenge") as String).fromBase64()
        registeredKeys = try? [RegisteredKeys](json: json ~> "registeredKeys")
        
        timeoutSeconds = try? json ~> "timeoutSeconds"
        requestId = try? json ~> "requestId"
        displayIdentifier = try? json ~> "displayIdentifier"
    }
}
