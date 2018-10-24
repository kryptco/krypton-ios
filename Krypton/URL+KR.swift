//
//  URL+KR.swift
//  Krypton
//
//  Created by Alex Grinman on 9/20/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

extension URL {
    func cleanPathComponents() -> [String] {
        return self.pathComponents.filter({ $0 != "/" }).filter({ !$0.isEmpty })
    }
    
    func queryItems() -> [String:String] {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
            else {
                return [:]
        }
        
        var found:[String:String] = [:]
        
        for queryItem in queryItems {
            if queryItem.value != nil {
                found[queryItem.name] = queryItem.value!
            }
        }
        
        return found
    }
    
}
