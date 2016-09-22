//
//  Github.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import OctoKit

class GitHub {
    
    var authConfig:OAuthConfiguration
    var accessToken:String?
    
    private let accessTokenKey = "github_token_key"
    
    init() {
        authConfig =  OAuthConfiguration(token: "ed1626f32b2945987427", secret: "eec8e5b957d2b0176cb61da87c32b99accd860eb", scopes: ["read:public_key", "write:public_key"])
        
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
    }
    
    
    func loginAndUpload() {
        authConfig.authenticate()
    }
    
    func upload(peer:Peer) {
        
    }
    
}
