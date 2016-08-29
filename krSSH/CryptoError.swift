//
//  SecStatus.swift
//  krSSH
//
//  Created by Alex Grinman on 8/28/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
//

import Foundation

//MARK: Crypto Error
enum CryptoError : ErrorType {
    case ACLCreate
    case Generate(OSStatus?)
    case Sign(OSStatus?)
    case Export(OSStatus?)
}


extension CryptoError {
    
    func getError() -> String {
        switch self {
        case .ACLCreate:
            return "error creating acl for keypair"
        case .Generate(let s):
            if let status = s {
                return parseOSStatus(status)
            }
            
            return "unknown error: generating key"
        case .Sign(let s):
            if let status = s {
                return parseOSStatus(status)
            }
            
            return "unknown error: signing"
        case .Export(let s):
            if let status = s {
                return parseOSStatus(status)
            }
            
            return "unknown error: exporting"
        default:
            return "unhandled error type"
        }
    }
}

func parseOSStatus(status: OSStatus) -> String {
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