//
//  OTPAuth.swift
//  KryptCodes
//
//  Created by Alex Grinman on 11/5/17.
//  Copyright © 2017 Alex Grinman. All rights reserved.
//

import Foundation
import JSON

class OTPAuth: Equatable, Hashable {
    
    enum Errors:Error {
        case invalidOTPType
        case invalidURL
        case invalidScheme
        case missingLabel
        case missingSecret
        case badSecretEncoding
        case unsupportedAlgorithm
    }
    
    enum Algorithm:String {
        case sha1 = "SHA1"
    }
    
    
    enum OTPType:String {
        case totp = "totp"
    }
    
    enum Defaults:Int {
        case digits = 6
        case period = 30
    }
    
    static let scheme = "otpauth"
    
    let string:String
    let properties:[String:String]
    
    let label:String
    let secret:[UInt8]
    let digits:HOTPDigits
    let period:Int
    let type:OTPType
    
    
    var id:String {
        return (Data(bytes: [UInt8](label.utf8)).SHA256 + Data(bytes: secret).SHA256).SHA256.toBase64(true)
    }
    
    init(urlString:String) throws {
        self.string = urlString
        
        guard let url = URL(string: urlString) else {
            throw Errors.invalidURL
        }
        
        guard url.scheme == OTPAuth.scheme else {
            throw Errors.invalidScheme
        }
        
        guard let host = url.host, let type = OTPType(rawValue: host) else {
            throw Errors.invalidOTPType
        }
        
        let query = url.queryItems()
        
        guard let secret = query["secret"] else {
            throw Errors.missingSecret
        }
        
        guard let secretBytes = base32Decode(secret) else {
            throw Errors.badSecretEncoding
        }
        
        if let digitsString = query["digits"], let digits = Int(digitsString) {
            self.digits = digits
        } else {
            self.digits = Defaults.digits.rawValue
        }
        
        if let periodString = query["period"], let period = Int(periodString) {
            self.period = period
        } else {
            self.period = Defaults.period.rawValue
        }
        
        guard url.pathComponents.count >= 2 else {
            throw Errors.missingLabel
        }
        
        self.label = url.pathComponents[1]
        self.secret = secretBytes
        self.type = type
        self.properties = url.queryItems()
    }
    
    var service:String {
        guard let issuer = properties["issuer"] else {
            return label.components(separatedBy: ":").first ?? label
        }
        return issuer
    }
    
    var account:String {
        let components =  label.components(separatedBy: ":")
        
        guard components.count >= 2 else {
            return label
        }
        
        return components[1]
    }
    
    func generateCode() throws -> HOTPCode {
        return try TOTP(secret: secret, digits: digits, period: period, time: Date())
    }
    
    static func ==(l: OTPAuth, r:OTPAuth) -> Bool {
        return l.id == r.id
    }
    
    var hashValue: Int {
        return string.hashValue
    }
}
