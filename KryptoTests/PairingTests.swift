//
//  PairingTests.swift
//  Kryptonite
//
//  Created by Alex Grinman on 3/3/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

import XCTest
@testable import Kryptonite

import Sodium
import JSON

class PairingTests: XCTestCase {
    
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testCreatePairing() {
        do {
            let pk = KRSodium.instance().box.keyPair()!.publicKey
            let _ = try Pairing(name: "test", workstationPublicKey: pk)
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testWrapPublicKey() {
        
        do {
            let kp = KRSodium.instance().box.keyPair()!
            let pairing = try Pairing(name: "test", workstationPublicKey: kp.publicKey)
            
            let wrappedPub = try pairing.keyPair.publicKey.wrap(to: kp.publicKey)
            
            // unwrapp pub
            
            let unwrapped = KRSodium.instance().box.open(anonymousCipherText: wrappedPub, recipientPublicKey: kp.publicKey, recipientSecretKey: kp.secretKey)!
            
            // ensure unwrapped == pairing.publicKey
            
            guard pairing.keyPair.publicKey.toBase64() == unwrapped.toBase64() else {
                XCTFail("Error: non matching unwrapped public key. \nGot: \(unwrapped.toBase64()). Expected: \(pairing.keyPair.publicKey.toBase64())")
                return
            }
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testSeal() {
        
        do {
            
            let kp = KRSodium.instance().box.keyPair()!
            let pairing = try Pairing(name: "test", workstationPublicKey: kp.publicKey)
            
            let dataStruct = TestStruct(p1: "hello", p2: "world")
            
            let sealed = try dataStruct.seal(to: pairing)
    
            let unsealed = KRSodium.instance().box.open(nonceAndAuthenticatedCipherText: sealed, senderPublicKey: pairing.keyPair.publicKey, recipientSecretKey: kp.secretKey)!
            
            let dataStructUnsealed = try TestStruct(jsonData: unsealed)
            // ensure sealed == unsealed
            
            guard dataStruct == dataStructUnsealed else {
                XCTFail("Error: non matching structures. \nGot: \(dataStructUnsealed). Expected: \(dataStruct)")
                return
            }
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testUnseal() {
        
        do {
            
            let kp = KRSodium.instance().box.keyPair()!
            let pairing = try Pairing(name: "test", workstationPublicKey: kp.publicKey)
            
            let dataStruct = TestStruct(p1: "hello", p2: "world")
            
            let sealed:Data = KRSodium.instance().box.seal(message: try dataStruct.jsonData(), recipientPublicKey: pairing.keyPair.publicKey, senderSecretKey: kp.secretKey)!
            
            let unsealed = try TestStruct(from: pairing, sealed: sealed)
            
            // ensure sealed == unsealed
            guard dataStruct == unsealed else {
                XCTFail("Error: non matching structures. \nGot: \(unsealed). Expected: \(dataStruct)")
                return
            }
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    
    func testVersionOrdering() {
        let v1 = Version(major: 2, minor: 0, patch: 0)
        let v2 = Version(major: 1, minor: 0, patch: 4)
        let v3 = Version(major: 2, minor: 4, patch: 1)
        let v4 = Version(major: 1, minor: 0, patch: 0)
        let v5 = Version(major: 1, minor: 0, patch: 0)
        let v6 = Version(major: 2, minor: 1, patch: 0)
        let v7 = Version(major: 2, minor: 1, patch: 1)
        
        XCTAssert(v4 == v5)
        XCTAssert(v1 > v5)
        XCTAssert(v3 > v1)
        XCTAssert(v3 > v2)
        XCTAssert(v2 > v5)
        XCTAssert(v7 > v6)
    }
}

struct TestStruct:Jsonable {
    var param1:String
    var param2:String
    
    init(p1:String, p2:String) {
        self.param1 = p1
        self.param2 = p2
    }
    
    init(json: Object) throws {
        param1 = try json ~> "1"
        param2 = try json ~> "2"
    }
    
    var object: Object {
        return ["1": param1, "2": param2]
    }
}

func ==(l:TestStruct, r:TestStruct) -> Bool {
    return l.param1 == r.param1 && l.param2 == r.param2
}


