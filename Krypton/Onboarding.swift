//
//  Onboarding.swift
//  Krypton
//
//  Created by Alex Grinman on 10/28/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Onboarding {
    
    static let startedKey = "ob_start_key"
    static let activeKey = "ob_state_key"
    
    static var hasStarted:Bool {
        get {
            guard let _ = try? KeychainStorage().get(key: startedKey)
                else {
                    return false
            }
            
            return true
        }
        set(active) {
            if active {
                try? KeychainStorage().set(key: startedKey, value: "true")
            } else {
                try? KeychainStorage().delete(key: startedKey)
            }
        }
    }

        
    static var isActive:Bool {
        get {
            guard let _ = try? KeychainStorage().get(key: activeKey)
            else {
                return false
            }
            
            return true
        }
        set(active) {
            if active {
                try? KeychainStorage().set(key: activeKey, value: "true")
            } else {
                try? KeychainStorage().delete(key: activeKey)
            }
        }
    }

    
}
