//
//  ASN1.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/18/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

// Some of the functions below are adapted from
// Heimdal (https://github.com/henrinormak/Heimdall)

struct ASN1 {
    let data:Data
    
    init(data:Data) {
        self.data = data
    }
    
    func parseSequenceOfTwoIntegers() throws -> (Data, Data) {
        
        let bytes = data.bytes

        var i:Int = 0
        
        // First there should be an ASN.1 SEQUENCE
        guard !bytes.isEmpty, bytes[0] == 0x30 else {
            throw CryptoError.encoding
        }
        
        i += 1

        // Total length of the container
        guard let _ = Int(octetBytes: bytes, startIdx: &i) else {
            throw CryptoError.encoding
        }
        
        var j = i+1

        // first component
        guard   bytes[i] == 0x02,
                let firstLength = Int(octetBytes: bytes, startIdx: &j),
                data.count >= j + firstLength
        
        else {
            throw CryptoError.encoding
        }
        
        let firstComponent = data.subdata(in: j ..< j+firstLength)
        j += firstLength

        var k = j+1

        // second component
        guard   bytes[j] == 0x02,
                let secondLength = Int(octetBytes: bytes, startIdx: &k),
                data.count >= k + secondLength
        else {
            throw CryptoError.encoding
        }
        
        let secondComponent = data.subdata(in: k ..< k+secondLength)

        return (firstComponent, secondComponent)
    }
}

//MARK: Encoding/Decoding lengths as octets
extension Int {
    func encodedOctets() -> [UInt8] {
        // Short form
        if self < 128 {
            return [UInt8(self)];
        }
        
        // Long form
        let i = (self / 256) + 1
        var len = self
        var result: [UInt8] = [UInt8(i + 0x80)]
        
        for _ in 0 ..< i {
            result.insert(UInt8(len & 0xFF), at: 1)
            len = len >> 8
        }
        
        return result
    }
    
    init?(octetBytes: [UInt8], startIdx: inout Int) {
        if octetBytes[startIdx] < 128 {
            // Short form
            self.init(octetBytes[startIdx])
            startIdx += 1
        } else {
            // Long form
            let octets = Int(octetBytes[startIdx]) - 128
            
            guard octetBytes.count > octets + startIdx else {
                return nil
            }
            
            var result = UInt64(0)
            
            for j in 1...octets {
                result = (result << 8)
                result = result + UInt64(octetBytes[startIdx + j])
            }
            
            startIdx += 1 + octets
            self.init(result)
        }
    }
}
