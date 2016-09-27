//
//  ASN1.swift
//  krSSH
//
//  Created by Alex Grinman on 9/25/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


// Some of the code below is adapted from
// Heimdal (https://github.com/henrinormak/Heimdall)
// Software Licence (14)


//MARK: Extract Modulus + Exponent

extension PublicKey {
    
    func splitIntoComponents() throws -> (modulus: Data, exponent: Data) {
        
        let data = try self.export()
        
        // Get the bytes from the keyData
        let pointer = UnsafePointer<CUnsignedChar>(data.bytes)
        let keyBytes = [CUnsignedChar](UnsafeBufferPointer<CUnsignedChar>(start:pointer, count:data.count / MemoryLayout<CUnsignedChar>.size))
        
        // Assumption is that the data is in DER encoding
        // If we can parse it, then return successfully
        var i: NSInteger = 0
        
        // First there should be an ASN.1 SEQUENCE
        if keyBytes[0] != 0x30 {
            throw CryptoError.encoding
        } else {
            i += 1
        }
        
        // Total length of the container
        if let _ = Int(octetBytes: keyBytes, startIdx: &i) {
            // First component is the modulus
            var j = i+1
            if keyBytes[i] == 0x02, let modulusLength = Int(octetBytes: keyBytes, startIdx: &j) {
                let modulus = data.subdata(in: j ..< j+modulusLength)
                j += modulusLength
                
                var k = j+1
                // Second should be the exponent
                if keyBytes[j] == 0x02, let exponentLength = Int(octetBytes: keyBytes, startIdx: &k) {
                    let exponent = data.subdata(in: k ..< k+exponentLength)
                    k += exponentLength
                    
                    return (modulus, exponent)
                }
            }
        }
        
        throw CryptoError.encoding
    }
    
}

//MARK: Encoding/Decoding lengths as octets
extension Int {
    func encodedOctets() -> [CUnsignedChar] {
        // Short form
        if self < 128 {
            return [CUnsignedChar(self)];
        }
        
        // Long form
        let i = (self / 256) + 1
        var len = self
        var result: [CUnsignedChar] = [CUnsignedChar(i + 0x80)]
        
        for _ in 0 ..< i {
            result.insert(CUnsignedChar(len & 0xFF), at: 1)
            len = len >> 8
        }
        
        return result
    }
    
    init?(octetBytes: [CUnsignedChar], startIdx: inout NSInteger) {
        if octetBytes[startIdx] < 128 {
            // Short form
            self.init(octetBytes[startIdx])
            startIdx += 1
        } else {
            // Long form
            let octets = Int(octetBytes[startIdx]) - 128
            
            if octets > octetBytes.count - startIdx {
                self.init(0)
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

