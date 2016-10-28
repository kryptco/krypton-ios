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
}
