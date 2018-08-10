//
//  DeveloperMode.swift
//  Krypton
//
//  Created by Alex Grinman on 8/8/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

struct DeveloperMode {
    static func setIfNeeded() {
        if !DeveloperMode.isSet {
            do {
                DeveloperMode.isOn = try KeyManager.hasKey()
                DeveloperMode.keepTeamsOn = try IdentityManager.hasTeam()
            } catch {
                log("error setting developer mode: \(error)", .error)
            }
        }
    }
    
    static func shouldShowTeamsTab() -> Bool {
        guard DeveloperMode.isOn else {
            return false
        }
        
        guard !DeveloperMode.keepTeamsOn else {
            return true
        }
        
        do {
            return try IdentityManager.hasTeam()
        } catch {
            log("error checking team identity: \(error)", .error)
            return false
        }
    }
    
    static func reset() {
        UserDefaults.group?.removeObject(forKey: Constants.developerModeKey)
        UserDefaults.group?.removeObject(forKey: Constants.developerModeTeamsKey)
    }
    

    static var isSet:Bool {
        return UserDefaults.group?.object(forKey: Constants.developerModeKey) != nil
    }
    
    static var isOn:Bool {
        get {
            return UserDefaults.group?.bool(forKey: Constants.developerModeKey) ?? false
        }
        
        set(v) {
            UserDefaults.group?.set(v, forKey: Constants.developerModeKey)
        }
    }
    
    static var keepTeamsOn:Bool {
        get {
            return UserDefaults.group?.bool(forKey: Constants.developerModeTeamsKey) ?? false
        }
        
        set(v) {
            UserDefaults.group?.set(v, forKey: Constants.developerModeTeamsKey)
        }
    }
}
