//
//  HOTP.swift
//  KryptCodes
//
//  Created by Alex Grinman on 11/4/17.
//  Copyright © 2017 Alex Grinman. All rights reserved.
//

import Foundation
import Security
import CommonCrypto

typealias SecretKey = [UInt8]
typealias Counter  = [UInt8]
typealias HOTPCode = String
typealias HOTPDigits = Int

enum HOTPError:Error {
    case invalidHMACLength(Int)
}


/// Generate an HOTP Value
/// Reference: https://tools.ietf.org/html/rfc4226
func HOTP(secretKey:SecretKey, counter:Counter, digits:HOTPDigits) throws -> HOTPCode {
    // 1: HMAC-SHA-1(K, C)
    var hs = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), secretKey, secretKey.count, counter, counter.count, &hs)

    // 2: Generate (Dynamic Truncation) s-num
    let sNum = try dynamicTruncation(hmac: hs)
    
    // 3: Generate an HOTP value
    let hotpValue = sNum % Int(pow(10, Double(digits)))

    return String(format: "%0\(digits)d", hotpValue)
}

func dynamicTruncation(hmac:[UInt8]) throws -> Int {
    guard hmac.count == CC_SHA1_DIGEST_LENGTH else {
        throw HOTPError.invalidHMACLength(hmac.count)
    }
    
    // low order 4 bits
    let offset = Int(hmac[Int(CC_SHA1_DIGEST_LENGTH) - 1] & 0x0F)
    var p = [UInt8](hmac[offset ... (offset + 3)])
    
    // zero the first bit
    p[0] = p[0] & 0x7F
    
    return Int(bigEndianBytes: p)
}


