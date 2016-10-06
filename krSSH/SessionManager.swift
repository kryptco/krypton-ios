//
//  SessionManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation


private var sharedSessionManager:SessionManager?

class SessionManager {
    
    private static let ListKey = "kr_session_list"
    
    
    
    private var sessions:[String:Session]
    init(_ sessions:[String:Session] = [:]) {
        self.sessions = sessions
    }
    
    class var shared:SessionManager {
        guard let sm = sharedSessionManager else {
            sharedSessionManager = SessionManager(SessionManager.load())
            return sharedSessionManager!
        }
        return sm
    }
    
    
    var all:[Session] {
        return [Session](sessions.values)
    }
    
    func get(queue:QueueName) -> Session? {
        return all.filter({$0.pairing.queue == queue}).first
    }
    
    func get(id:String) -> Session? {
        return sessions[id]
    }
    
    func get(deviceName:String) -> Session? {
        return all.filter({ $0.pairing.name == deviceName }).first
    }
    
    
    func add(session:Session) {
        let didSave = KeychainStorage().set(key: session.id, value: session.pairing.symmetricKey.toBase64())
        if !didSave { log("could not save keys for id: \(session.id)", .error) }
        sessions[session.id] = session
        save()
    }
    
    func remove(session:Session) {
        sessions.removeValue(forKey: session.id)
        save()
    }
    
    func destory() {
        UserDefaults.standard.removeObject(forKey: SessionManager.ListKey)
        sharedSessionManager = nil
        sessions = [:]
    }
    
    
    func save() {
        let data = sessions.values.map({ $0.jsonMap }) as [Any]
        UserDefaults.standard.set(data, forKey: SessionManager.ListKey)
        UserDefaults.standard.synchronize()
    }
    
    
    private class func load() -> [String:Session] {
        guard let jsonList = UserDefaults.standard.array(forKey: SessionManager.ListKey) as? [JSON]
        else {
            return [:]
        }
        
        var map:[String:Session] = [:]
        do {
            let sessions = try jsonList.map({try Session(json: $0)})
            sessions.forEach({ map[$0.id] = $0 })
        } catch {
            log("could not parse sessions from persistant storage", .error)
        }

        
        return map
    }
}
