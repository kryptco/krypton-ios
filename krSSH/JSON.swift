//
//  JSON.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

enum JSONParsingError:Error {
    case invalid
    case invalidValue(k:String, v:Any)
    case missingKey(String)
}

extension JSONParsingError {
    func message() -> String {
        switch self {
        case .invalid:
            return "invalid json object"
        case .invalidValue(let (k,v)):
            return "invalid object value: \(v) for key: \(k)"
        case .missingKey(let k):
            return "missing dictionary key: \(k)"
        }
    }
}

typealias JSON = [String:Any]
protocol JSONConvertable {
    init(json:JSON) throws
    var jsonMap:JSON { get }
}

extension JSONConvertable {
    
    func jsonData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: jsonMap)
    }
    func jsonString() throws -> String {
        let jsonData = try self.jsonData()
        
        guard let json = String(data: jsonData, encoding: String.Encoding.utf8)
        else {
            throw JSONParsingError.invalid
        }

        return json
    }
}
infix operator <~
func ~><T>(map: JSON, key:String) throws -> T {
    guard let value = map[key] as? T else {
        throw JSONParsingError.missingKey(key)
    }
    
    return value
}
