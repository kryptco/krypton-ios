//
//  Hash.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CommonCrypto
extension Data {
    var SHA256:Data {
        var dataBytes = self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
    var SHA1:Data {
        var dataBytes = self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
}
