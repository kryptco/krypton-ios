//
//  SSHUtil.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/9/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

typealias SSHMessage = Data
struct SSHMessageParsingError:Error {}

extension SSHMessage {
    
    mutating func popByte() throws -> UInt8 {
        guard self.count >= 1 else {
            throw SSHMessageParsingError()
        }
        
        let out = self.bytes[0]
        
        if self.count > 1 {
            self = self.subdata(in: 1 ..< self.count)
        } else {
            self = Data()
        }
        
        return out
    }
    
    mutating func popBool() throws -> Bool {
        return (try self.popByte() == 1) ? true : false
    }

    
    mutating func popData() throws -> Data {
        guard self.count >= 4 else {
            throw SSHMessageParsingError()
        }
        
        let lenBigEndianBytes = self.subdata(in: 0 ..< 4)
        guard let len = UInt32(exactly: Int32(bigEndianBytes: [UInt8](lenBigEndianBytes))) else {
            throw SSHMessageParsingError()
        }
        let start = 4
        let end = start + Int(len)
        
        guard self.count >= end else {
            throw SSHMessageParsingError()
        }
        let out = self.subdata(in: start ..< end )
        
        if self.count > end {
            self = self.subdata(in: end ..< self.count)
        } else {
            self = Data()
        }
        
        return out
    }
    
    mutating func popString() throws -> String {
        guard let out = String(bytes: try self.popData(), encoding: .utf8) else {
            throw SSHMessageParsingError()
        }
        
        return out
    }
}

public extension UInt32 {
    init(bigEndianBytes: [UInt8]) {
        let count = UInt32(bigEndianBytes.count)
        
        var val : UInt32 = 0
        for i in UInt32(0) ..< count {
            val += UInt32(bigEndianBytes[Int(i)]) << ((count - 1 - i) * 8)
        }
        self.init(val)
    }
}
