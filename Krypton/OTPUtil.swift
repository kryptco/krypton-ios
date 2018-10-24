//
//  Util.swift
//  KryptCodes
//
//  Created by Alex Grinman on 11/5/17.
//  Copyright © 2017 Alex Grinman. All rights reserved.
//

import Foundation

extension UInt64 {
    var eightByteCounter:Counter {
        var bytes:[UInt8] = []
        
        for i in (0 ..< 8).reversed() {
            let shift = UInt64(8*i)
            bytes.append(UInt8((self >> shift) % 256))
        }
        
        return bytes
    }
}

extension Int {
    init(bigEndianBytes: [UInt8]) {
        let count = Int(bigEndianBytes.count)
        
        var val:Int = 0
        for i in 0 ..< count {
            val += Int(bigEndianBytes[i]) << ((count - 1 - i) * 8)
        }
        
        self = val
    }
}

