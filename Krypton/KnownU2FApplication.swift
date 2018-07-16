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
    case twitter = "https://twitter.com/account/login_verification/u2f_trusted_facets.json"
    case stripe = "https://dashboard.stripe.com/u2f-facets"
    case dropbox = "https://www.dropbox.com/u2f-app-id.json"
    case github = "https://github.com/u2f/trusted_facets"
    case gitlab = "https://gitlab.com"
    case yubicoDemo = "https://demo.yubico.com"
    case duoDemo = "https://api-9dcf9b83.duosecurity.com"
    case keeper = "https://keepersecurity.com"
    case fedora = "https://id.fedoraproject.org/u2f-origins.json"
    case bitbucket = "https://bitbucket.org"
    case sentry = "https://sentry.io/auth/2fa/u2fappid.json"
    
    // for webauthn
    static var RPIDMap:[String:KnownU2FApplication] = [
        "www.dropbox.com": .dropbox
    ]
    
    static var common:[KnownU2FApplication] = [.google, .facebook, .dropbox, .twitter, .stripe, .github, .gitlab, .bitbucket, .sentry]
    
    var displayName:String {
        switch self {
        case .google:
            return "google.com"
        case .facebook:
            return "facebook.com"
        case .twitter:
            return "twitter.com"
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
        case .keeper:
            return "keepersecurity.com"
        case .fedora:
            return "id.fedoraproject.org"
        case .bitbucket:
            return "bitbucket.com"
        case .sentry:
            return "sentry.io"
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
        case .duoDemo:
            return "dd"
        case .yubicoDemo:
            return "yd"
        case .sentry:
            return "sy"
        case .twitter:
            return "tw"
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
        
        // match alternatives
        if let app = KnownU2FApplication.RPIDMap[app] {
            self = app
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
        case .twitter:
            return 3
        case .github:
            return 4
        case .stripe:
            return 5
        case .gitlab:
            return 6
        case .bitbucket:
            return 7
        case .sentry:
            return 8
        case .keeper:
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
