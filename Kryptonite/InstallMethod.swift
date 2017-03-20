//
//  InstallMethod.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

enum InstallMethod:String {
    case brew = "brew install kryptco/tap/kr"
    case npm = "npm install -g krd"
    case curl = "curl https://krypt.co/kr | sh"
    
    
    @available(iOS, deprecated: 1.0, message: "Testflight only, change to production install instruction before app store release.")
    var command:String {
        return UpgradeMethod.beta.rawValue
        //return self.rawValue
    }
}

enum UpgradeMethod:String {
    case beta = "curl https://krypt.co/kr-beta | sh"
    case prod = "kr upgrade"
    
    @available(iOS, deprecated: 1.0, message: "Testflight only, change to production upgrade instruction before app store release.")
    static var current:String {
        //WARNING: change before app store release
        return UpgradeMethod.beta.rawValue
    }
}
