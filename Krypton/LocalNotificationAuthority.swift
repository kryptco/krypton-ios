//
//  LocalNotificationAuthority.swift
//  Krypton
//
//  Created by Alex Grinman on 1/7/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import Sodium
import JSON

class LocalNotificationAuthority {
    
    internal struct SignedLocalRequest {
        let localRequestJSON:String
        let signature:Data
    }
    
    enum Errors:Error {
        case signingKeyGenFailed
        case signatureCreationFailed
        case badLocalRequestSignature
        case missingSigningKey
    }
    
    class VerifiedLocalRequest:LocalRequestBody {}
    class UnverifiedLocalRequest:LocalRequestBody {}
    
    private static let signingKeyIdentifier = "local_notification_auth_signing_key"
    
    static func getOrCreateSigningKey() throws -> Auth.SecretKey {
        do {
            let signingKey = try KeychainStorage().getData(key: signingKeyIdentifier)
            return signingKey

        } catch KeychainStorageError.notFound {
            // create the key
            log("local notification signing key not found...creating one now", .warning)
            
            guard let signingKey = KRSodium.instance().auth.key() else {
                throw Errors.signingKeyGenFailed
            }
            
            try KeychainStorage().setData(key: signingKeyIdentifier, data: signingKey)
            return signingKey
        }
    }
    
    static func getSigningKey() throws -> Auth.SecretKey {
        do {
            let signingKey = try KeychainStorage().getData(key: signingKeyIdentifier)
            return signingKey
        } catch KeychainStorageError.notFound {
            throw Errors.missingSigningKey
        }
    }
    

    static func createSignedPayload(for verifiedLocalRequest:VerifiedLocalRequest) throws -> [String:Any] {
        
        let jsonString = try verifiedLocalRequest.jsonString()
        let jsonData = try jsonString.utf8Data()
        let signingKey = try getOrCreateSigningKey()
        
        guard let signature = KRSodium.instance().auth.tag(message: jsonData, secretKey: signingKey) else {
            throw Errors.signatureCreationFailed
        }
        
        let localRequest = SignedLocalRequest(localRequestJSON: jsonString, signature: signature)
        return localRequest.object
    }
    
    static func verifyLocalNotification(with payload:[String:Any]) throws -> VerifiedLocalRequest {
        
        let rawRequest = try SignedLocalRequest(json: payload)
        let rawRequestData = try rawRequest.localRequestJSON.utf8Data()
        
        let signingKey = try getSigningKey()
        
        guard KRSodium.instance().auth.verify(message: rawRequestData, secretKey: signingKey, tag: rawRequest.signature)
        else {
            throw Errors.badLocalRequestSignature
        }
        
        let verifiedLocalRequest = try VerifiedLocalRequest(jsonData: rawRequestData)
        return verifiedLocalRequest
    }
    
    static func parseUnverifiedLocalNotification(with payload:[String:Any]) throws -> UnverifiedLocalRequest {
        let rawRequest = try SignedLocalRequest(json: payload)
        return try UnverifiedLocalRequest(jsonString: rawRequest.localRequestJSON)
    }
}

extension LocalNotificationAuthority.SignedLocalRequest:Jsonable {
    init(json: Object) throws {
        localRequestJSON = try json ~> "r"
        signature = try ((json ~> "s") as String).fromBase64()
    }
    
    var object: Object {
        return ["r": localRequestJSON, "s": signature.toBase64()]
    }
}


class LocalRequestBody:Jsonable {
    let alertText:String
    let request:Request
    let sessionID:String
    let sessionName:String
    
    init(alertText:String, request:Request, sessionID:String, sessionName:String) {
        self.alertText = alertText
        self.request = request
        self.sessionID = sessionID
        self.sessionName = sessionName
    }
    
    convenience required init(json: Object) throws {
        try self.init(alertText: json ~> "a",
                      request: Request(json: json ~> "r"),
                      sessionID: json ~> "sid",
                      sessionName: json ~> "sn")
    }
    
    var object: Object {
        return ["a": alertText,
                "r": request.object,
                "sid": sessionID,
                "sn": sessionName]
    }

}


