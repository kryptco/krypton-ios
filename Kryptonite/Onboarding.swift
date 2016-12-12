//
//  Onboarding.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/28/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

struct Onboarding {
    
    private static let mutex = Mutex()
    static let key = "ob_state_key"
    
    static var isActive:Bool {
        get {
            mutex.lock()
            defer { mutex.unlock() }

            guard let _ = try? KeychainStorage().get(key: key)
            else {
                return false
            }
            
            return true
        }
        set(active) {
            mutex.lock()
            defer { mutex.unlock() }

            if active {
                let _ = KeychainStorage().set(key: key, value: "true")
            } else {
                let _ = KeychainStorage().delete(key: key)
            }
        }
    }

    
}
