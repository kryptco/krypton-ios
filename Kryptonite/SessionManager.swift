//
//  SessionManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON


//MARK: Defaults

extension UserDefaults {
    static var sessionDefaults:UserDefaults? {
        return UserDefaults(suiteName: "kr_session_defaults")
    }
}

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
        let didSavePub = KeychainStorage().set(key: Session.KeychainKey.pub.tag(for: session.id), value: session.pairing.keyPair.publicKey.toBase64())
        let didSavePriv = KeychainStorage().set(key: Session.KeychainKey.priv.tag(for: session.id), value: session.pairing.keyPair.secretKey.toBase64())

        if !(didSavePub && didSavePriv) { log("could not save keypair for id: \(session.id)", .error) }
        sessions[session.id] = session
        save()
    }
    
    func remove(session:Session) {
        sessions.removeValue(forKey: session.id)
        save()
    }
    
    func destory() {
        UserDefaults.group?.removeObject(forKey: SessionManager.ListKey)
        sharedSessionManager = nil
        sessions = [:]
    }
    
    
    func save() {
        let data = sessions.values.map({ $0.object }) as [Any]
        UserDefaults.group?.set(data, forKey: SessionManager.ListKey)
        UserDefaults.group?.synchronize()
    }
    
    
    private class func load() -> [String:Session] {
        guard let jsonList = UserDefaults.group?.array(forKey: SessionManager.ListKey) as? [Object]
        else {
            return [:]
        }
        
        var map:[String:Session] = [:]
        do {
            try [Session](json: jsonList).forEach({ map[$0.id] = $0 })
        } catch {
            log("could not parse sessions from persistant storage", .error)
        }

        
        return map
    }
}
