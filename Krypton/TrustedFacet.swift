//
//  TrustedFacet.swift
//  Krypton
//
//  Created by Alex Grinman on 8/19/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

import JSON
import SwiftHTTP

struct TrustedFacet {
    struct Version {
        let major:Int
        let minor:Int
    }
    
    let ids:[String]
    let version:Version
}

enum TrustedFacetResponse {
    case ok([TrustedFacet])
    case error(Error)
}

extension TrustedFacet {
    static func load(for appId:String, baseOnReturnURL:String, onCompletion:@escaping (TrustedFacetResponse) -> Void) {
        HTTP.GET(appId) { (response) in
            if let err = response.error {
                onCompletion(.error(err))
                return
            }

            do {
                let json:Object = try JSON.parse(data: response.data)
                let trustedFacets = try [TrustedFacet](json: json ~> "trustedFacets")
                onCompletion(.ok(trustedFacets))
            } catch {
                onCompletion(.error(error))
            }
        }
    }
}

extension TrustedFacet.Version:JsonReadable {
    init(json: Object) throws {
        major = try json ~> "major"
        minor = try json ~> "minor"
    }
}

extension TrustedFacet:JsonReadable {    
    init(json: Object) throws {
        version = try Version(json: json ~> "version")
        ids = try json ~> "ids"
    }
}
