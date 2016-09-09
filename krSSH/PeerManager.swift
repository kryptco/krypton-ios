//
//  PeerManager.swift
//  krSSH
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


private var sharedPeerManager:PeerManager?
private var datastore = NSUbiquitousKeyValueStore()

class PeerManager {
    
    private static let ListKey = "kr_peer_list"
    
    private var peers:[String:Peer]
    init(_ peers:[String:Peer] = [:]) {
        self.peers = peers
    
        NotificationCenter.default.addObserver(self, selector: #selector(PeerManager.datastoreDidChangeExternally), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: datastore)

    }
    
    class var shared:PeerManager {
        guard let pm = sharedPeerManager else {
            sharedPeerManager = PeerManager(PeerManager.loadPeers())
            return sharedPeerManager!
        }
        return pm
    }
    
    
    var all:[Peer] {
        return [Peer](peers.values)
    }
    
    func add(peer:Peer) {
        let success = KeychainStorage().set(key: peer.fingerprint, value: peer.publicKey)
        if !success {
            log("failed to save \(peer)", LogType.error)
        }
        peers[peer.fingerprint] = peer
        
        save()
    }
    
    func remove(peer:Peer) {
        let success = KeychainStorage().delete(key: peer.fingerprint, value: peer.publicKey)
        if !success {
            log("failed to delete \(peer)", LogType.error)
        }
        peers.removeValue(forKey: peer.fingerprint)
        
        save()
    }
    
    func destory() {
        datastore.removeObject(forKey: PeerManager.ListKey)
        sharedPeerManager = nil
        peers = [:]
    }
    
    
    func save() {
        var peerDict = [String:AnyObject]()
        
        for (_, peer) in peers {
            peerDict[peer.fingerprint] = ["email": peer.email,
                                          "fingerprint": peer.fingerprint,
                                          "date_added": Double(peer.dateAdded.timeIntervalSince1970)] as AnyObject
        }
        
        datastore.set(peerDict, forKey: PeerManager.ListKey)
        datastore.synchronize()
    }

    
    dynamic func datastoreDidChangeExternally() {
        sharedPeerManager = nil
    }
    
    
    private class func loadPeers() -> [String:Peer] {
        guard let peerDictList = datastore.dictionary(forKey: PeerManager.ListKey) as? [String:AnyObject]
        else {
            return [:]
        }
        
        var peers = [String:Peer]()
        
        for (_, peerDict) in peerDictList {
            
            guard   let map = peerDict as? [String:AnyObject],
                    let email = map["email"] as? String,
                    let fp = map["fingerprint"] as? String,
                    let seconds = map["date_added"] as? Double
            else {
                log("could not parse: \(peerDict)", .error)
                continue
            }
            
            let date = Date(timeIntervalSince1970: seconds)
            var publicKey:String
            
            do {
                publicKey = try KeychainStorage().get(key: fp)
                let foundFingerprint = try publicKey.fingerprint().toBase64()

                guard foundFingerprint == fp
                else {
                    log("invalid public key found: \(publicKey)", .error)
                    continue
                }
            } catch (let e) {
                log("error retrieving public key: \(e)", .error)
                continue
            }
            
            
            let peer = Peer(email: email, fingerprint: fp, publicKey: publicKey, date: date)
            peers[peer.fingerprint] = peer
        }
        
        
        return peers
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: datastore)
    }
    
    
}
