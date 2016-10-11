//
//  Links.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation




enum LinkType:String {
    case kr = "kr"
    case file = "file"
}


enum LinkCommand:String {
    case request = "request"
    case `import` = "import"
    case none = ""

    static let all = [request, `import`]

    
    init(url:URL) {
        guard
            let commandParam = url.queryItems()["c"],
            let command = LinkCommand(rawValue: commandParam)
        else {
            self = .none
            return
        }
        
        self = command
    }

}
class Link {
    let type:LinkType
    let command:LinkCommand
    let properties:[String:String]
 
    let url:URL
    
    init?(url:URL) {
        guard
            let scheme = url.scheme,
            let type = LinkType(rawValue: scheme)
        else {
            return nil
        }
        
        self.url = url
        self.type = type
        self.command = LinkCommand(url: url)
        self.properties = url.queryItems()
    }
    
    static var notificationName:NSNotification.Name {
        return NSNotification.Name("app_link_notification")
    }

}

extension Link {
    static func publicKeyRequest() -> String {
        let email = (try? KeyManager.sharedInstance().getMe().email)?.data(using: String.Encoding.utf8)?.toBase64(true)
        return "\(Properties.shared.requestKeyURLBase)\(email ?? "")"
    }
    
    static func publicKeyImport() -> String {
        let me = try? KeyManager.sharedInstance().getMe()
        
        let email = me?.email.data(using: String.Encoding.utf8)?.toBase64(true)
        let publicKeyWire = me?.publicKey.toBase64() ?? ""
        
        return "\(LinkType.kr.rawValue)://?c=\(LinkCommand.import.rawValue)&pk=\(publicKeyWire)&e=\(email ?? "")"
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
