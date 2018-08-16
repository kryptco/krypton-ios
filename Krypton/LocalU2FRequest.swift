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
    let challenge:String
    let registeredKeys:[RegisteredKeys]?
    
    let timeoutSeconds:Double?
    let requestId:Double?
    let displayIdentifier:String?
    
    enum Errors:Error {
        case unknownRequestType
        case noKnownKeyHandle
        case invalidCallbackURL
    }
    
    enum RequestType:String {
        case register = "u2f_register_request"
        case sign = "u2f_sign_request"
    }
    
    struct RegisteredKeys {
        let keyHandle:Data
    }
    
    struct ClientData {
        let typ:String
        let challenge:String
        let origin:String

        static func createRegister(challenge:String, origin:String) throws -> String {
            return try ClientData(typ: "navigator.id.finishEnrollment",
                                  challenge: challenge,
                                  origin: origin).jsonString()
        }

        static func createAuthenticate(challenge:String, origin:String) throws -> String {
            return try ClientData(typ: "navigator.id.getAssertion",
                                  challenge: challenge,
                                  origin: origin).jsonString()
        }
    }
    
    struct Response {
        let type:String
        let requestId:Double?
        let responseData:ResponseData
    }
    
    enum ResponseData {
        case register(RegisterResponseData)
        case sign(SignResponseData)
    }
    
    struct RegisterResponseData {
        let version:String
        let registrationData:Data
        let clientData:Data
    }
    
    struct SignResponseData {
        let keyHandle:Data
        let signatureData:Data
        let clientData:Data
    }
    
    func getSignedCallback(returnURL:String) throws -> URL {
        
        switch type {
        case .register:
            let clientData = try ClientData.createRegister(challenge: challenge, origin: appId)
            let requestChallenge = Data(bytes: [UInt8](clientData.utf8)).SHA256
            
            struct Unimpl:Error {}
            throw Unimpl()
            
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
            
            let clientData = try ClientData.createAuthenticate(challenge: challenge, origin: "ios:bundle-id:com.google.GoogleAccounts")
            let clientDataBytes = Data(bytes: [UInt8](clientData.utf8))
            let requestChallenge = clientDataBytes.SHA256
            
            
            let keypair = try U2FKeyManager.keyPair(for: keyHandle)
            let counter = try U2FKeyManager.fetchAndIncrementCounter(keyHandle: keyHandle)
            
            let signature = try keypair.signU2FAuthentication(application: appId.hash, counter: counter, challenge: requestChallenge)
            
            try U2FAccountManager.updateLastUsed(account: appId)
            
            // create the signatureData
            
            var signatureData = Data()
            signatureData.append(0x01)
            signatureData.append(UInt8((counter >> 24) & 0xff))
            signatureData.append(UInt8((counter >> 16) & 0xff))
            signatureData.append(UInt8((counter >> 8) & 0xff))
            signatureData.append(UInt8((counter >> 0) & 0xff))
            signatureData.append(signature)

            let response = Response(type: "u2f_sign_response",
                                    requestId: requestId,
                                    responseData: .sign(SignResponseData(keyHandle: keyHandle,
                                                                         signatureData: signatureData,
                                                                         clientData: Data(bytes: [UInt8](clientData.utf8)))))
            
            try? log("Response JSON: \(response.jsonString(prettyPrinted: true))")
            let responseJson = try response.jsonString()
            
            let returnUrlFixed = returnURL.replacingOccurrences(of: "cid=3", with: "cid=4")
            guard   let challengeResponseFragment = responseJson.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
                    let url = URL(string: "\(returnUrlFixed)#chaldt=\(challengeResponseFragment)")
            else {
                    throw Errors.invalidCallbackURL
            }
            
            log("Fragment: \(challengeResponseFragment)")
            return url
        }
        
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
        challenge = try json ~> "challenge"
        registeredKeys = try? [RegisteredKeys](json: json ~> "registeredKeys")
        
        timeoutSeconds = try? json ~> "timeoutSeconds"
        requestId = try? json ~> "requestId"
        displayIdentifier = try? json ~> "displayIdentifier"
    }
}

extension LocalU2FRequest.ClientData:JsonWritable {
    var object: Object {
        return ["typ": typ,
                "challenge": challenge,
                "origin": origin]
    }
}

extension LocalU2FRequest.Response:JsonWritable {
    var object: Object {
        var obj:Object = ["type": type, "responseData": responseData.object]
        
        if let requestId = requestId {
            obj["requestId"] = requestId
        }
        
        return obj
    }
}
extension LocalU2FRequest.ResponseData:JsonWritable {
    var object: Object {
        switch self {
        case .register(let register):
            return register.object
        case .sign(let sign):
            return sign.object
        }
    }
}

extension LocalU2FRequest.RegisterResponseData:JsonWritable {
    var object: Object {
        return ["version": version,
                "registrationData": registrationData.toBase64(true),
                "clientData": clientData.toBase64(true)]
    }
}

extension LocalU2FRequest.SignResponseData:JsonWritable {
    var object: Object {
        return ["keyHandle": keyHandle.toBase64(true),
                "signatureData": signatureData.toBase64(true),
                "clientData": clientData.toBase64(true)]
    }
}


