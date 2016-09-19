//
//  KryptoTests.swift
//  KryptoTests
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
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
            let _ = try KeyPair.destroy("test")
            let _ = try KeyPair.generate("test")

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
            
            let _ = try KeyPair.destroy("test")
            let _ = try KeyPair.generate("test")
            guard let _ = try KeyPair.load("test")
            else {
                XCTFail("test failed: no KeyPair loaded")
                return
            }

        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testGenDestroy() {
        do {
            let _ = try KeyPair.destroy("test")
            let _ = try KeyPair.generate("test")
            
            let result = try KeyPair.destroy("test")
            let lkp = try KeyPair.load("test")
            
            XCTAssert(result && lkp == nil, "destroying keypair failed")
            
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
            let _ = try KeyPair.destroy("test")
            let kp = try KeyPair.generate("test")
            let sig = try kp.sign(data: "hellllo".data(using: String.Encoding.utf8)!)
            
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
    
    
    
    
    func testLoadSignVerify() {
        do {
            let _ = try KeyPair.destroy("test")
            let _ = try KeyPair.generate("test")

            guard let loadedKp = try KeyPair.load("test")
                else {
                    XCTFail("test failed: no KeyPair loaded")
                    return
            }
            
            let sig = try loadedKp.sign(data: "hellllo".data(using: String.Encoding.utf8)!)
            let resYes = try loadedKp.publicKey.verify("hellllo", signature: sig)
        
            XCTAssert(resYes, "sig is supposed to be correct!")
            
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
            let _ = try KeyPair.destroy("test")
            let kp = try KeyPair.generate("test")
            
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
    
    
    func testGenSignExportVerify() {
        
        do {
            let _ = try KeyPair.destroy("test")
            let kp = try KeyPair.generate("test")
            let sig = try kp.sign(data: "hellllo".data(using: String.Encoding.utf8)!)

            let pub = try kp.publicKey.exportSecp()
            let impPubKey = try PublicKey.importFrom("test", publicKeyDER: pub)
            
            let resYes = try impPubKey.verify("hellllo", signature: sig)
            XCTAssert(resYes, "sig is supposed to be correct!")
            
            let resNo = try impPubKey.verify("byyyye", signature: sig)
            XCTAssert(!resNo, "sig is supposed to be wrong!")
            
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testCertImport() {
        
        let pkEC = "MIIBejCCASACCQDSO7zy24AZ8jAKBggqhkjOPQQDAjBFMQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMB4XDTE2MDkxOTE4MjQ0MVoXDTE3MDkxOTE4MjQ0MVowRTELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoMGEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABGArL+kB/QB/ZYeBKtynsEfTISuXUIkQxRqyWgsHdG8tGjETk6ZmdWU731/iACDXmxxf7pk+GttL+32dvU24rVQwCgYIKoZIzj0EAwIDSAAwRQIhAN4LR6vRiVOPlDVyyVB96c7KU027fccHNntzJp5kuJ7GAiBF1A3e10odlauvR0EoIqiM2kax29G3JvJCM+VFX7PmCw==".fromBase64()!
        
        let pub = try? PublicKey(certData: pkEC)
        log(pub)
    }
    
    func testPublicKeyExportImport() {
        
        do {
            let _ = try KeyPair.destroy("test")
            let kp = try KeyPair.generate("test")
            
            let pub = try kp.publicKey.exportSecp()
            let pub2 = try PublicKey.importFrom("test", publicKeyDER: pub)
            
            let pub2secp = try pub2.exportSecp()
            XCTAssert(pub == pub2secp, "public keys don't match after import export")

        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testSealUnseal() {
        
        do {
            let key : Key = try Data.random(size: 32)
            let c = try "hello friends".data(using: String.Encoding.utf8)!.seal(key: key)
            
            let d = try c.unseal(key: key)
            let ds = String(data: d, encoding: String.Encoding.utf8)!
            
            XCTAssert(ds == "hello friends", "plaintexts don't match!")
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    func testSealUnsealIntegrity() {
        
        do {
            let key = try Data.random(size: 32)
            let c = try "hello friends".data(using: String.Encoding.utf8)!.seal(key: key)
            
            let key2 = try Data.random(size: 32)
            let d = try c.unseal(key: key2)
            
            let ds = String(data: d, encoding: String.Encoding.utf8)!
            
            XCTAssert(ds == "hello friends", "plaintexts don't match!")
            
        }
        catch CryptoError.integrity {
            XCTAssert(true)
        }
        catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
}
