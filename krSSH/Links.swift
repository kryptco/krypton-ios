//
//  Links.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation



// Request URL ->
// kr://request?email=aasda@sddfsd.com
// kr://request?phone=6173712321



enum AppLinkType:String {
    case github = "kr-github"
    case kryptonite = "kr"
    case file = "file"
}


enum LinkCommand:String {
    case request = "request"
    case `import` = "import"

    static let all = [request, `import`]

    var notificationName:NSNotification.Name {
        return NSNotification.Name("\(self.rawValue)_app_link_notification")
    }
}
class Link {
    let command:LinkCommand
    let properties:[String:String]
 
    init?(url:URL) {
        guard
            let command = LinkCommand(rawValue: url.host ?? ""),
            url.scheme == AppLinkType.kryptonite.rawValue
        else {
            return nil
        }
        
        self.command = command
        self.properties = url.queryItems()
    }
}

extension Link {
    static func publicKeyRequest() -> String {
        let email = (try? KeyManager.sharedInstance().getMe().email)?.data(using: String.Encoding.utf8)?.toBase64(true)
        return "\(AppLinkType.kryptonite.rawValue)://\(LinkCommand.request.rawValue)?r=\(email ?? "")"
    }
    
    static func publicKeyImport() -> String {
        let me = try? KeyManager.sharedInstance().getMe()
        
        let email = me?.email.data(using: String.Encoding.utf8)?.toBase64(true)
        let publicKeyWire = me?.publicKey.toBase64() ?? ""
        
        return "\(AppLinkType.kryptonite.rawValue)://\(LinkCommand.import.rawValue)?pk=\(publicKeyWire)&e=\(email ?? "")"
    }

}

class LinkListener {
    var onListen:(Link)->()
    
    init(_ onListen: @escaping (Link)->()) {
        self.onListen = onListen
        
        for command in LinkCommand.all {
            NotificationCenter.default.addObserver(self, selector: #selector(LinkListener.didReceive(note:)), name: command.notificationName, object: nil)
        }
        
        if let pending = (UIApplication.shared.delegate as? AppDelegate)?.pendingLink
        {
            //remove the pending url
            (UIApplication.shared.delegate as? AppDelegate)?.pendingLink = nil
            onListen(pending)
        }
    }
    
    deinit {
        for command in LinkCommand.all {
            NotificationCenter.default.removeObserver(self, name: command.notificationName, object: nil)
        }
    }
    
    dynamic func didReceive(note:NSNotification) {
        guard let link = note.object as? Link else {
            return
        }
        
        (UIApplication.shared.delegate as? AppDelegate)?.pendingLink = nil
        onListen(link)
    }
}


extension URL {
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
