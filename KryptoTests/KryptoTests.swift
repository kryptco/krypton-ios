//
//  KryptoTests.swift
//  KryptoTests
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
//

import XCTest

class KryptoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGen() {
        
        do {
            let _ = try KeyPair.generate("test123", keySize: 256, accessGroup: nil)
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testGenSignVerify() {
        
        do {
            let kp = try KeyPair.generate("test", keySize: 256, accessGroup: nil)
            let sig = try kp.sign("hellllo")
            
            let resYes = try kp.publicKey.verify("hellllo", signature: sig)
            XCTAssert(resYes, "sig is supposed to be correct!")
            
            let resNo = try kp.publicKey.verify("byyyye", signature: sig)
            XCTAssert(!resNo, "sig is supposed to be wrong!")

        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testPublicKeyExport() {

        do {
            let kp = try KeyPair.generate("test1234", keySize: 256, accessGroup: nil)
            
            let rawPub = try kp.publicKey.export()
            print(rawPub)
            
            let secpPub = try kp.publicKey.exportSecp()
            print(secpPub)
            
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testExample() {
    }
    
    /*func testPerformanceExample() {
        self.measureBlock {
        }
    }*/
    
}
