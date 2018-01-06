//
//  Hash.swift
//  Krypton
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CommonCrypto

extension Data {
    var SHA512:Data {
        var dataBytes = self.bytes
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
    var SHA384:Data {
        var dataBytes = self.bytes
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA384_DIGEST_LENGTH))
        CC_SHA384(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
    
    var SHA256:Data {
        var dataBytes = self.bytes
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
    
    var SHA224:Data {
        var dataBytes = self.bytes
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
        CC_SHA224(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
    
    var SHA1:Data {
        var dataBytes = self.bytes
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(&dataBytes, CC_LONG(self.count), &hash)
        
        return Data(bytes: hash)
    }
}
