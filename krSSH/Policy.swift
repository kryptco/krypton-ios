//
//  Policy.swift
//  krSSH
//
//  Created by Alex Grinman on 9/14/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


class Policy {
    
    enum StorageKey:String {
        case userApproval = "policy_user_approval"
    }
    
    class var needsUserApproval:Bool {
        set(val) {
            UserDefaults.standard.set(val, forKey: StorageKey.userApproval.rawValue)
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.bool(forKey: StorageKey.userApproval.rawValue) 
        }
    }
}
