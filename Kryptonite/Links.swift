//
//  Links.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

<<<<<<< HEAD



=======
>>>>>>> team invite accept checkpoint
enum LinkType:String {
    case kr = "kr"
}

<<<<<<< HEAD
enum LinkCommand:String {
    case share = "share"
    case none = ""
    
    static let all = [share]

    
    init(url:URL) {
        guard
            let commandParam = url.queryItems()["c"],
            let command = LinkCommand(rawValue: commandParam)
        else {
            self = .none
            return
=======
enum LinkError:Error {
    case invalidType
    case invalidCommand
}

enum LinkCommand:String {
    case joinTeam = "join_team"
    
    init(url:URL) throws {
        guard   let commandString = url.host,
                let command = LinkCommand(rawValue: commandString)
        else {
            throw LinkError.invalidCommand
>>>>>>> team invite accept checkpoint
        }
        
        self = command
    }

}
class Link {
    let type:LinkType
    let command:LinkCommand
<<<<<<< HEAD
    let properties:[String:String]
 
    let url:URL
    
    init?(url:URL) {
=======
    
    let path:[String]
    let properties:[String:String]
    
    let url:URL
    
    init(url:URL) throws {
>>>>>>> team invite accept checkpoint
        guard
            let scheme = url.scheme,
            let type = LinkType(rawValue: scheme)
        else {
<<<<<<< HEAD
            return nil
=======
            throw LinkError.invalidType
>>>>>>> team invite accept checkpoint
        }
        
        self.url = url
        self.type = type
<<<<<<< HEAD
        self.command = LinkCommand(url: url)
        self.properties = url.queryItems()
=======
        self.command = try LinkCommand(url: url)
        self.properties = url.queryItems()
        log(url.pathComponents)
        self.path = url.pathComponents.filter({ $0 != "/" }).filter({ !$0.isEmpty })
        log(self.path)
>>>>>>> team invite accept checkpoint
    }
    
    static var notificationName:NSNotification.Name {
        return NSNotification.Name("app_link_notification")
    }
<<<<<<< HEAD

}

extension Link {

=======
>>>>>>> team invite accept checkpoint
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
