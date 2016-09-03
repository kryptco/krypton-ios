//
//  SecStatus.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation

//MARK: Crypto Error
enum CryptoError : Error {
    case paramCreate
    case generate(OSStatus?)
    case sign(OSStatus?)
    case export(OSStatus?)
    case load(OSStatus?)
    case destroy(OSStatus?)
    case tagExists
    case encoding
    case random

}


extension CryptoError {
    
    func getError() -> String {
        switch self {
        case .paramCreate:
            return "error creating params for keypair"
        case .generate(let s):
            if let status = s {
                return parseOSStatus(status)
            }
            
            return "unknown error: generating key"
        case .sign(let s):
            if let status = s {
                return parseOSStatus(status)
            }
            
            return "unknown error: signing"
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
