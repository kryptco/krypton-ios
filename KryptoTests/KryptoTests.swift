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
    
    func testLoad() {
        do {
            let kp = try KeyPair.generate("testabcd", keySize: 256, accessGroup: nil)
            let pub = try kp.publicKey.exportSecp()
            
            guard let loadedKp = try KeyPair.load("testabcd", publicKeyDER: pub)
            else {
                XCTFail("test failed: no KeyPair loaded")
                return
            }
            let sig = try loadedKp.sign("hellllo")

            let resYes = try kp.publicKey.verify("hellllo", signature: sig)

            XCTAssert(resYes, "sig is supposed to be correct!")

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
    
    func testPublicKeyImport() {
        
        let pkEC = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEkzVpXcGl9E9vaX5T42LwcqkQo7xnlofns8EwG_QHr6S9iivyO00G56oCny5GiD59_nPIdiPWMEmXq4vTpRxvJw=="
        
        let pkRSA = "MIIBCgKCAQEA2Ddg4jCLE7VPxLPjBaTPH3DSXpkJQP3J5KycZBUF4dyWJTeY8m5HyTrRj+Dm5t3ccpPJSd+OjupHdUj+BtL+8g+NOddmUCr0gmQsxsXx8ex+lS+wHgRBmH/Cb/5lZ1Ml7Omtysz8G/pw6LGYK9C0s0ZoUOAApv/rC9vQ1T8S0eJPJIB8rHsfnvrxkC9Cwkftu5pOIv5fqrjsDLqn0dLypWyT8AhHSdgRZn0658efTyPytfnu2/1XiOzzCbNxPExv+n8fq1kkzSIg9+gN7tvPz+gpbv1eQsDkArrGx838EqW8o5cUbGA3DtlGWAr4dKTe3yY40CA55AMz/lvmU0dnRwIDAQAB"


        do {
            let _ = try PublicKey.importFrom(publicKeyDER: pkEC)
            let _ = try PublicKey.importFrom(publicKeyDER: pkRSA)

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
