//
//  CryptoError.swift
//  Krypton
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation

//MARK: Crypto Error
enum CryptoError : Error {
    case paramCreate
    case generate(KeyType, OSStatus?)
    case sign(KeyType, OSStatus?)
    case unsupportedSignatureDigestAlgorithmType
    case encrypt
    case decrypt
    case export(OSStatus?)
    case publicKeyImport(KeyType)
    case load(KeyType, OSStatus?)
    case destroy(KeyType, OSStatus?)
    case tagExists
    case encoding
    case random
    case integrity
    case fingerprint
    case certImport
    case keyNotFound
    case badAccess
    case verify(KeyType)
}


extension CryptoError {
    
    func getError() -> String {
        switch self {
        case .paramCreate:
            return "error creating params for keypair"
        case .generate(let t, let s):
            if let status = s {
                return "\(parseOSStatus(status))\(t.rawValue)"
            }
            
            return "unknown error: generating key \(t.rawValue)"
        case .sign(let t, let s):
            if let status = s {
                return "\(parseOSStatus(status))\(t.rawValue)"
            }
            
            return "unknown error: signing \(t.rawValue)"
        case .encoding:
            return "encoding error"
            
        case .export(let s):
            if let status = s {
                return parseOSStatus(status)
            }
            
            return "unknown error: exporting"
        default:
            return "unhandled error type"
        }
    }
}

func parseOSStatus(_ status: OSStatus) -> String {
    switch status {
    case errSecSuccess:
        return "success"
    case errSecNotAvailable:
        return "not available"
    case errSecIO:
        return "io"
    case errSecOpWr:
        return "opwr"
    case errSecParam:
        return "param"
    case errSecBadReq:
        return "badreq"
    case errSecAuthFailed:
        return "auth"
    case errSecAllocate:
        return "allocate"
    case errSecInteractionNotAllowed:
        return "interaction"
    case errSecInternalComponent:
        return "internal"
    default:
        return "unknown: \(status)"
    }
}
