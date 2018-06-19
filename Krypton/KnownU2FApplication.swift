//
//  File.swift
//  Krypton
//
//  Created by Alex Grinman on 5/3/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

enum KnownU2FApplication:String {
    case google = "https://www.gstatic.com/securitykey/origins.json"
    case facebook = "https://www.facebook.com/u2f/app_id/?uid="
    case stripe = "https://dashboard.stripe.com/u2f-facets"
    case dropbox = "https://www.dropbox.com/u2f-app-id.json"
    case github = "https://github.com/u2f/trusted_facets"
    case gitlab = "https://gitlab.com"
    case yubicoDemo = "https://demo.yubico.com"
    case duoDemo = "https://api-9dcf9b83.duosecurity.com"
    case keeper = "https://keepersecurity.com"
    case fedora = "https://id.fedoraproject.org/u2f-origins.json"
    case vaultBitwarden = "https://vault.bitwarden.com/app-id.json"
    case bitbucket = "https://bitbucket.org"
    
    static var common:[KnownU2FApplication] = [.google, .facebook, .stripe, .dropbox, .github, .gitlab, .bitbucket]
    
    var displayName:String {
        switch self {
        case .google:
            return "google.com"
        case .facebook:
            return "facebook.com"
        case .github:
            return "github.com"
        case .stripe:
            return "dashboard.stripe.com"
        case .dropbox:
            return "dropbox.com"
        case .gitlab:
            return "gitlab.com"
        case .yubicoDemo:
            return "demo.yubico.com"
        case .duoDemo:
            return "api-9dcf9b83.duosecurity.com"
        case .vaultBitwarden:
            return "vault.bitwarden.com"
        case .keeper:
            return "keepersecurity.com"
        case .fedora:
            return "id.fedoraproject.org"
        case .bitbucket:
            return "bitbucket.com"
        }
    }
    
    var shortName:String {
        switch self {
        case .bitbucket:
            return "b"
        case .dropbox:
            return "d"
        case .facebook:
            return "f"
        case .fedora:
            return "fd"
        case .github:
            return "gh"
        case .gitlab:
            return "gl"
        case .google:
            return "g"
        case .keeper:
            return "kp"
        case .stripe:
            return "s"
        case .vaultBitwarden:
            return "vb"
        case .duoDemo:
            return "dd"
        case .yubicoDemo:
            return "yd"
        }
    }
}

extension KnownU2FApplication {
    init?(for app:U2FAppID) {
        
        // special case for facebook's unique per user facet
        if  let url = URL(string: app),
            url.host == "www.facebook.com" && app.hasPrefix(KnownU2FApplication.facebook.rawValue)
        {
            self = .facebook
            return
        }
        
        guard let known = KnownU2FApplication(rawValue: app) else {
            return nil
        }
        
        self = known
    }
    
    var order:Int {
        switch self {
        case .facebook:
            return 0
        case .google:
            return 1
        case .dropbox:
            return 2
        case .github:
            return 3
        case .stripe:
            return 4
        case .gitlab:
            return 5
        case .bitbucket:
            return 6
        case .keeper:
            return 7
        case .duoDemo:
            return 8
        case .fedora:
            return 9
        default:
            return 10
        }
    }
}

extension U2FAppID {
    var order:Int {
        return KnownU2FApplication(for: self)?.order ?? 99
    }
}
