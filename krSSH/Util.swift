//
//  Util.swift
//  krSSH
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
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
    func fromBase64() -> Data? {
        var urlDecoded = self
        urlDecoded = urlDecoded.replacingOccurrences(of: "_", with: "/")
        urlDecoded = urlDecoded.replacingOccurrences(of: "-", with: "+")
        
        return Data(base64Encoded: urlDecoded, options: NSData.Base64DecodingOptions(rawValue: 0))
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
