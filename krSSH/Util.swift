//
//  Util.swift
//  krSSH
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
//

import Foundation

extension NSData {
    func toBase64(urlEncoded:Bool = true) -> String {
        var result = self.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        
        if urlEncoded {
            result = result.stringByReplacingOccurrencesOfString("/", withString: "_")
            result = result.stringByReplacingOccurrencesOfString("+", withString: "-")
        }
        
        return result
    }
    
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

extension NSMutableData {
    override func byteArray() -> [String] {
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
    func fromBase64() -> NSData? {
        var urlDecoded = self
        urlDecoded = urlDecoded.stringByReplacingOccurrencesOfString("_", withString: "/")
        urlDecoded = urlDecoded.stringByReplacingOccurrencesOfString("-", withString: "+")
        
        return NSData(base64EncodedString: urlDecoded, options: NSDataBase64DecodingOptions(rawValue: 0))
    }
}
