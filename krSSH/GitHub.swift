//
//  Github.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import OctoKit

protocol GitHubError:Error {
    var message:String { get }
}
struct NotAuthenticatedError:GitHubError{
    var message = "not logged in to GitHub"
}
struct ApiError:GitHubError{
    var message:String
    
    init(error:Error) {
        let errors = ((error as NSError).userInfo["RequestKitErrorResponseKey"] as? [String:Any])?["errors"] as? [[String:Any]]
        self.message = (errors?.first?["message"] as? String) ?? "unknown"
    }
}

class GitHub {
    
    var authConfig:OAuthConfiguration
    var accessToken:String?
    
    private let accessTokenKey = "github_token_key"
    
    init() {
        authConfig =  OAuthConfiguration(token: "ed1626f32b2945987427", secret: "eec8e5b957d2b0176cb61da87c32b99accd860eb", scopes: ["read:public_key", "write:public_key"])
        
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
    }
    
    
    
    func getToken(url:URL, completion:@escaping ()->()) {
        GitHub().authConfig.handleOpenURL(url: url) { (tokenConfig) in
    
            if let token = tokenConfig.accessToken {
                self.accessToken = token
                UserDefaults.standard.set(token, forKey: self.accessTokenKey)
                UserDefaults.standard.synchronize()
            }
            
            completion()
        }
    }
    
    func upload(title:String, publicKeyWire:String, success:@escaping ()->(), failure:@escaping (GitHubError)->()) {
        
        guard let token = accessToken else {
            failure(NotAuthenticatedError())
            return
        }

        let tokenConfig = TokenConfiguration(token)
        let _ = Octokit(tokenConfig).postPublicKey(publicKey: publicKeyWire, title: title, completion: { (resp) in
            switch resp {
            case .success(let msg):
                log("github success: \(msg)")
                success()
                
                
            case .failure(let e):
                log("github error: \(e)", .error)
                failure(ApiError(error: e))
    
            }
        })

    }
    
}
