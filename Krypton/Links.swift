//
//  Links.swift
//  Krypton
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

enum CopyToken {
    case joinTeam(SodiumSecretBoxKey)
    
    enum Errors:Error {
        case tooShort
        case badPrefix
    }
    
    enum Prefix:String {
        case joinTeam = "JT"
        
        static var length:Int { return 2 }
    }
    
    init(string:String) throws {
        guard string.count > Prefix.length else {
            throw Errors.tooShort
        }
        
        switch Prefix(rawValue: String(string.prefix(Prefix.length))) {
        case .some(.joinTeam):
            self = try .joinTeam(String(string.suffix(from: string.index(string.startIndex, offsetBy: Prefix.length))).fromBase64())
        case .none:
            throw Errors.badPrefix
        }
    }
    
    var string:String {
        switch self {
        case .joinTeam(let secret):
            return "\(Prefix.joinTeam.rawValue)\(secret.toBase64())"
        }
    }
    
    var link:String {
        switch self {
        case .joinTeam(let secret):
            return SigChain.Link.invite(SigChain.JoinTeamInvite(symmetricKey: secret)).string(for: Constants.appURLScheme)
        }
    }
}

enum LinkType:String {
    case app = "krypton"
    case site = "https"
    case u2fGoogle = "u2f-google"
    case u2fGoogleChrome = "u2f-x-callback"
    case u2f = "u2f"
}
            
enum LinkError:Error {
    case invalidType
    case invalidCommand
}

struct LinkCommand {
    
    enum Host:String {
        case joinTeam = "join_team"
        case emailChallenge = "verify_email"
        case emailChallengeRemote = "krypt.co"
        case auth = "auth"
        case googleChromeCallback = "x-callback-url"
        
        func matchesPathIfNeeded(of url:URL) -> Bool {
            switch self {
            case .joinTeam, .emailChallenge, .auth:
                return true // url validation done individually
            case .googleChromeCallback:
                return url.cleanPathComponents() == ["auth"]
            case .emailChallengeRemote:
                return url.cleanPathComponents() == ["app", "verify_email.html"]
            }
        }
    }
    
    let host:Host
    
    init(url:URL) throws {
        guard   let hostString = url.host,
                let host = Host(rawValue: hostString),
                host.matchesPathIfNeeded(of: url)
        else {
            throw LinkError.invalidCommand
        }
        
        self.host = host
    }
}

class Link {
    let type:LinkType
    let command:LinkCommand
    let path:[String]
    let properties:[String:String]
    let sourceAppBundleID:String?
    let url:URL
    
    init(url:URL, sourceAppBundleID:String? = nil) throws {
        guard
            let scheme = url.scheme,
            let type = LinkType(rawValue: scheme)
        else {
            throw LinkError.invalidType
        }
        
        self.url = url
        self.sourceAppBundleID = sourceAppBundleID
        self.type = type
        self.command = try LinkCommand(url: url)
        self.properties = url.queryItems()
        self.path = url.cleanPathComponents()
        log(self.path)
    }
    
    static var notificationName:NSNotification.Name {
        return NSNotification.Name("app_link_notification")
    }

}


class LinkListener {
    var onListen:(Link)->()
    
    init(_ onListen: @escaping (Link)->()) {
        self.onListen = onListen
        
        NotificationCenter.default.addObserver(self, selector: #selector(LinkListener.didReceive(note:)), name: Link.notificationName, object: nil)

        
        if let pending = (UIApplication.shared.delegate as? AppDelegate)?.pendingLink
        {
            //remove the pending url
            (UIApplication.shared.delegate as? AppDelegate)?.pendingLink = nil
            onListen(pending)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Link.notificationName, object: nil)
    }
    
    @objc dynamic func didReceive(note:NSNotification) {
        guard let link = note.object as? Link else {
            log("empty link in link notification", .error)
            return
        }
        
        dispatchMain {
            (UIApplication.shared.delegate as? AppDelegate)?.pendingLink = nil
        }
        
        self.onListen(link)
    }
}


extension URL {
    func cleanPathComponents() -> [String] {
        return self.pathComponents.filter({ $0 != "/" }).filter({ !$0.isEmpty })
    }
    func queryItems() -> [String:String] {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else {
            return [:]
        }
            
        var found:[String:String] = [:]
        
        for queryItem in queryItems {
            if queryItem.value != nil {
                found[queryItem.name] = queryItem.value!
            }
        }
        
        return found
    }

}
