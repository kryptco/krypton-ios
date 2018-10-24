//
//  Pair.swift
//  Krypton
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import Sodium
import JSON

typealias QueueName = String

struct Pairing:JsonReadable {

    var name:String
    var uuid: UUID
    var queue:String {
        return uuid.uuidString.uppercased()
    }
    var workstationPublicKey:Box.PublicKey
    var keyPair:Box.KeyPair
    
    var browser:Browser?
    
    var displayName:String {
        return name.removeDotLocal()
    }
    
    var workstationPublicKeyDoubleHash:Data {
        return workstationPublicKey.SHA256.SHA256
    }
    
    var version:Version?
    
    /// Cache key pair seeds for pairing with the same machine
    private static var keychain = KeychainStorage(service: "pairing_keypair_cache")
    
    /// Keyed by the workstation public key hash
    private static func keychainKey(for workstationPublicKey: Box.PublicKey) -> String {
        return "seed_\(workstationPublicKey.SHA256.toBase64(true))"
    }
    
    init(name: String, workstationPublicKey:Box.PublicKey, version:Version? = nil, browser: Browser? = nil) throws {
        
        var keyPair:Box.KeyPair
        
        do {
            let keyPairSeed = try Pairing.keychain.getData(key: Pairing.keychainKey(for: workstationPublicKey))
            
            guard let kp = KRSodium.instance().box.keyPair(seed: keyPairSeed.bytes) else {
                throw CryptoError.generate(KeyType.Ed25519, nil)
            }
            
            keyPair = kp

        } catch KeychainStorageError.notFound {
            let keyPairSeed = try Data.random(size: KRSodium.instance().box.SeedBytes)
            try Pairing.keychain.setData(key: Pairing.keychainKey(for: workstationPublicKey), data: keyPairSeed)
            
            guard let kp = KRSodium.instance().box.keyPair(seed: keyPairSeed.bytes) else {
                throw CryptoError.generate(KeyType.Ed25519, nil)
            }
            
            keyPair = kp
        } catch {
            throw error
        }
        
        try self.init(name: name, workstationPublicKey: workstationPublicKey, keyPair: keyPair, version: version, browser: browser)
    }
    
    /// removes the cached key pair seed in from the pairing keychain
    func removeCachedSeed() throws {
        try Pairing.keychain.delete(key: Pairing.keychainKey(for: workstationPublicKey))
    }

    init(name: String, workstationPublicKey:Box.PublicKey, keyPair:Box.KeyPair, version:Version? = nil, browser: Browser? = nil) throws {
        self.workstationPublicKey = workstationPublicKey
        self.keyPair = keyPair
        self.name = name
        self.uuid = NSUUID(uuidBytes: workstationPublicKey.SHA256.subdata(in: 0 ..< 16).bytes) as UUID
        self.version = version
        self.browser = browser
    }

    init(json: Object) throws {
        let pkB64:String = try json ~> "pk"
        let workstationPublicKey = try pkB64.fromBase64()
        
        var version:Version?
        if let v:String = try? json ~> "v" {
            version = try Version(string: v)
        }

        let browser:Browser? = try? Browser(json: json)
        
        try self.init(name: json ~> "n", workstationPublicKey: workstationPublicKey.bytes, version:version, browser: browser)
    }
}

struct Browser {
    enum Kind:String {
        case chrome = "chrome"
        case safari = "safari"
        case firefox = "firefox"
        case edge = "edge"
    }
    
    enum Errors:Error {
        case undefinedBrowser
    }
    
    let deviceIdentifier:Data
    let kind:Kind
}

extension Browser:Jsonable {
    init(json: Object) throws {
        deviceIdentifier = try ((json ~> "d") as String).fromBase64()
        
        guard let browserKind = try Kind(rawValue: json ~> "b") else {
            throw Browser.Errors.undefinedBrowser
        }
        
        kind = browserKind
    }
    
    var object: Object {
        return ["d": deviceIdentifier.toBase64(), "b": kind.rawValue]
    }
}

struct PairingQR {
    
    private static let urlScheme = "https"
    private static let urlHost = "get.krypt.co"
    
    enum Kind {
        case url
        case json
    }
    
    enum Errors:Error {
        case invalidURLPrefix
        
    }
    
    let pairing:Pairing
    let kind:Kind
    
    init(with string:String) throws {
        
        // first check if the string is a url
        // otherwise assume it's just json
        guard let url = URL(string: string) else {
            pairing = try Pairing(jsonString: string)
            kind = .json

            return
        }
        
        guard   let fragment = url.fragment,
                url.scheme == PairingQR.urlScheme &&
                url.host == PairingQR.urlHost
        else {
            throw Errors.invalidURLPrefix
        }
        
        pairing = try Pairing(jsonData: fragment.fromBase64())
        kind = .url
    }
}

