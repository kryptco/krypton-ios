//
//  Util.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation

extension Data {
    func toBase64(_ urlEncoded:Bool = false) -> String {
        var result = self.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        if urlEncoded {
            result = result.replacingOccurrences(of: "/", with: "_")
            result = result.replacingOccurrences(of: "+", with: "-")
        }
        
        return result
    }
    
    func byteArray() -> [String] {
        var array:[String] = []
        
        for i in 0 ..< self.count  {
            var byte: UInt8 = 0
            (self as NSData).getBytes(&byte, range: NSMakeRange(i, 1))
            array.append(NSString(format: "%d", byte) as String)
        }
        
        return array
    }
    
    var hex:String {
        let bytes = self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }
        
        var hexString = ""
        for i in 0..<self.count {
            hexString += String(format: "%02x", bytes[i])
        }
        return hexString
    }
    
    var hexPretty:String {
        let bytes = self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }
        
        
        var hex = ""
        for i in 0..<self.count {
            hex += String(format: "%02x ", bytes[i])
        }
                
        return hex.uppercased()
    }
    
    var bytes:[UInt8] {
        return self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }
    }
}

extension NSMutableData {
    func byteArray() -> [String] {
        var array:[String] = []
        
        for i in 0 ..< self.length  {
            var byte: UInt8 = 0
            self.getBytes(&byte, range: NSMakeRange(i, 1))
            array.append(NSString(format: "%d", byte) as String)
        }
        
        return array
    }
}

extension String {
    func fromBase64() throws -> Data {
        var urlDecoded = self
        urlDecoded = urlDecoded.replacingOccurrences(of: "_", with: "/")
        urlDecoded = urlDecoded.replacingOccurrences(of: "-", with: "+")
        
        guard let data = Data(base64Encoded: urlDecoded, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
            throw CryptoError.encoding
        }
        
        return data
    }
}

extension SecKey {
    func getAttributes() throws -> CFDictionary? {
        var attrs : AnyObject?
        let copyStatus = SecItemCopyMatching([
            String(kSecReturnAttributes): kCFBooleanTrue,
            String(kSecValueRef): self,
            ] as CFDictionary, &attrs)
        if !copyStatus.isSuccess() {
            throw CryptoError.export(copyStatus)
        }
        guard let presentAttrs = attrs else {
            return nil
        }
        return (presentAttrs as! CFDictionary)
    }
}

extension OSStatus {
    func isSuccess() -> Bool {
        return self == noErr || self == errSecSuccess
    }
}

extension Data {
    func bigEndianByteSize() -> [UInt8] {
        return stride(from: 24, through: 0, by: -8).map {
            UInt8(truncatingBitPattern: UInt32(self.count).littleEndian >> UInt32($0))
        }
    }
}

extension Int32 {
    init(bigEndianBytes: [UInt8]) {
        if bigEndianBytes.count < 4 {
            self.init(0)
            return
        }
        var val : Int32 = 0
        for i in Int32(0)..<4 {
            val += Int32(bigEndianBytes[Int(i)]) << ((3 - i) * 8)
        }
        self.init(val)
    }
}

// Some of the function below is adapted from
// Heimdal (https://github.com/henrinormak/Heimdall)
// Software Licence (14)

//MARK: Extract Modulus + Exponent

extension RSAPublicKey {
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
