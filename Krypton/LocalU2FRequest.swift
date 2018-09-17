//
//  LocalU2FRequest.swift
//  Krypton
//
//  Created by Alex Grinman on 8/6/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct LocalU2FApproval {
    let request:LocalU2FRequest
    let trustedFacets:[TrustedFacet]
    let callback:Callback
    
    struct ChromeCallback {
        let successCallbackURL:String
        let errorCallbackURL:String
        let originURL:String
    }
    
    typealias ReturnURL = String
    
    enum Callback {
        case https(ReturnURL)
        case googleChrome(ChromeCallback)
    }
}

struct LocalU2FRequest {
    let type:RequestType
    let appId:String
    let challenge:String
    let registeredKeys:[RegisteredKeys]?
    
    let timeoutSeconds:Double?
    let requestId:Int64?
    let displayIdentifier:String?
    
    
    enum Errors:Error {
        case unknownRequestType
        case noKnownKeyHandle
        case invalidCallbackURL
        case unsupportedRequestType
        case returnURLDoesNotTrustedFacets
        case invalidReturnURL
        case onlyGoogleCurrentlySupported
    }
    


    
    enum RequestType:String {
        case register = "u2f_register"
        case sign = "u2f_sign"
        
        init(type:String) throws {
            guard let reqType = RequestType(rawValue: type.replacingOccurrences(of: "_request", with: "")) else {
                throw Errors.unknownRequestType
            }
            
            self = reqType
        }
        
        var request:String {
            return "\(self.rawValue)_request"
        }
        
        var response:String {
            return "\(self.rawValue)_response"
        }
    }
    
    struct RegisteredKeys {
        let keyHandle:Data
    }
    
    struct ClientData {
        let typ:String
        let challenge:String
        let origin:String

        static func createAuthenticate(challenge:String, origin:String) throws -> String {
            return try ClientData(typ: "navigator.id.getAssertion",
                                  challenge: challenge,
                                  origin: origin).jsonString()
        }
    }
    
    struct Response {
        let type:String
        let requestId:Int64?
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
    
    func verifyOrigin(returnURL:String, trustedFacets:[TrustedFacet]) throws {
        guard   let url = URL(string: returnURL),
                let scheme = url.scheme,
                let host = url.host
        else {
            throw Errors.invalidReturnURL
        }
        
        guard case .some(.google) = KnownU2FApplication(for: appId) else {
            throw Errors.onlyGoogleCurrentlySupported
        }
        
        let thisFacet = "\(scheme)://\(host)"
        
        /// Temporary whitelist google as it is the only RP
        /// that supports U2F auth locally on iOS
        guard thisFacet == "https://accounts.google.com" else {
            throw Errors.returnURLDoesNotTrustedFacets
        }
    }
    
    func verifyOriginAndGetSignedCallbackURL(callback:LocalU2FApproval.Callback, trustedFacets:[TrustedFacet]) throws -> URL {
        
        // verify the origin
        switch callback {
        case .https(let returnURL):
            try verifyOrigin(returnURL: returnURL, trustedFacets: trustedFacets)

        case .googleChrome(let chromeCallback):
            try verifyOrigin(returnURL: chromeCallback.originURL, trustedFacets: trustedFacets)
        }
        
        switch type {
        case .register:
            throw Errors.unsupportedRequestType
            
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
            
            let localOrigin = KnownU2FApplication(for: appId)?.localRequestOrigin() ?? appId
            let clientData = try ClientData.createAuthenticate(challenge: challenge,
                                                               origin: localOrigin)
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

            
            switch callback {
            case .https(let returnURL):
                let response = Response(type: RequestType.sign.response,
                                        requestId: requestId,
                                        responseData: .sign(SignResponseData(keyHandle: keyHandle,
                                                                             signatureData: signatureData,
                                                                             clientData: Data(bytes: [UInt8](clientData.utf8)))))
                
                let responseJson = try response.jsonString()
                
                guard
                    let challengeResponseFragment = responseJson.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
                    let url = URL(string: "\(returnURL)#chaldt=\(challengeResponseFragment)")
                    else {
                        throw Errors.invalidCallbackURL
                }
                
                return url

            case .googleChrome(let chromeCallback):
                
                let keyHandleParam = keyHandle.toBase64(true, pad: false)
                let signatureDataParam = signatureData.toBase64(true, pad: false)
                let clientDataParam = Data(bytes: [UInt8](clientData.utf8)).toBase64(true, pad: false)
                
                guard   let requestId = self.requestId,
                        let url = URL(string: "\(chromeCallback.successCallbackURL)&keyHandle=\(keyHandleParam)&requestId=\(requestId)&signatureData=\(signatureDataParam)&clientData=\(clientDataParam)")
                else {
                    throw Errors.invalidCallbackURL
                }
                
                return url
            }
        }
    }
}

extension KnownU2FApplication {
    func localRequestOrigin() -> String? {
        switch self {
        case .google:
            return "ios:bundle-id:com.google.GoogleAccounts"
        default:
            return nil
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
        type = try RequestType(type: json ~> "type")
        appId = try json ~> "appId"
        challenge = try json ~> "challenge"
        registeredKeys = try? [RegisteredKeys](json: json ~> "registeredKeys")
        
        timeoutSeconds = try? json ~> "timeoutSeconds"
        requestId = try? json ~> "requestId"
        displayIdentifier = try? json ~> "displayIdentifier"
    }
}

extension LocalU2FRequest.ClientData:Jsonable {
    init(json: Object) throws {
        typ = try json ~> "typ"
        challenge = try json ~> "challenge"
        origin = try json ~> "origin"
    }
    
    var object: Object {
        return ["typ": typ,
                "challenge": challenge,
                "origin": origin]
    }
}

extension LocalU2FRequest.Response:Jsonable {
    init(json: Object) throws {
        type = try json ~> "type"
        requestId = try? json ~> "requestId"
        responseData = try LocalU2FRequest.ResponseData(json: json ~> "responseData")
    }
    var object: Object {
        var obj:Object = ["type": type,
                          "responseData": responseData.object]
        
        if let requestId = requestId {
            obj["requestId"] = requestId
        }
        
        return obj
    }
}
extension LocalU2FRequest.ResponseData:Jsonable {
    init(json: Object) throws {
        if let sign = try? LocalU2FRequest.SignResponseData(json: json) {
            self = .sign(sign)
            return
        }
        
        self = try .register(LocalU2FRequest.RegisterResponseData(json: json))
    }
    
    var object: Object {
        switch self {
        case .register(let register):
            return register.object
        case .sign(let sign):
            return sign.object
        }
    }
}

extension LocalU2FRequest.RegisterResponseData:Jsonable {
    init(json: Object) throws {
        version = try json ~> "version"
        registrationData = try ((json ~> "registrationData") as String).fromBase64()
        clientData = try ((json ~> "clientData") as String).fromBase64()
    }

    var object: Object {
        return ["version": version,
                "registrationData": registrationData.toBase64(true, pad: false),
                "clientData": clientData.toBase64(true, pad: false)]
    }
}

extension LocalU2FRequest.SignResponseData:Jsonable {
    init(json: Object) throws {
        keyHandle = try ((json ~> "keyHandle") as String).fromBase64()
        signatureData = try ((json ~> "signatureData") as String).fromBase64()
        clientData = try ((json ~> "clientData") as String).fromBase64()
    }

    var object: Object {
        return ["keyHandle": keyHandle.toBase64(true, pad: false),
                "signatureData": signatureData.toBase64(true, pad: false),
                "clientData": clientData.toBase64(true, pad: false)]
    }
}


