//
//  KryptoTests.swift
//  KryptoTests
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
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
            
            let secpPub = try kp.publicKey.export().toBase64()
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

            let pub = try kp.publicKey.export().toBase64()
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
    
    
    func testPublicKeyExportImport() {
        
        do {
            let _ = try KeyPair.destroy("test")
            let kp = try KeyPair.generate("test")
            
            let pub = try kp.publicKey.export().toBase64()
            let pub2 = try PublicKey.importFrom("test", publicKeyDER: pub)
            
            let pub2secp = try pub2.export().toBase64()
            XCTAssert(pub == pub2secp, "public keys don't match after import export")

        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
    }
    
    
    func testImportPublicKeyDER() {
        
        do {
            
            let _ = try KeyPair.destroy("test")

            let pkRSA = "MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0fAZp+DuQKltrL5b0NPY9awpDVbg4aEedPKsAGReE1d/m96OvlswV5WOjd9sz7Qr0q1WxM+LHbIiORRLrEunHaSdkICVWc7SLV8LI/vsxIs+x8w/2llreutAVFBwhU5I4SK9bFdlDu1BTxQi83oRiM2oECqOZd34qCww16TmnSCLKUeRDigB4bSwgav807BB+wDi5Pg6FneI41XyQY+TaMtEm+h3fxnE+J+2XlG4tuwAv7n2N4lN2gsl2b1PITtQgzeeHRjpDKFVfhUApacCIu3Ia8kaQXDKC6zCBCk8pbWcLtrp35a8G/WPqgxvvVsGrWHmY1gtTwVhOYk5AtkaUjGudWspoTRO5lB59IGNhsr4xcSwK/SbxgYelB/Lj7GLIuxUZLwRZm+jjK7BlKg5883YrwZmTg5BFcjOLw7phbygrPyf7HzUMFyZaBr5dLN5m5nzUs1lxIY/moRkmcZKsxPOfh2DO91kdess7U6/wXowfB3OS1jme2cpefX8pTfxfVLZJxf7Qpll6PZLpMyg5zLnEIkvzwicHK0CJeA94p6eaXtO53li3psrYRvRrxAS5TkyHOR6//EOfxsBLol7jHpAkMEN6ljs9uivSEH/TYW+itde10StIZ36IXmJsHvDEi6AqM01QGz4aI55V9zLk7GkiJOVh3IueAuAvlt7syMCAwEAAQ=="
            
            let _ = try PublicKey.importFrom("test", publicKeyDER: pkRSA)
            
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
        
        
    }
    
    // MARK: Seal
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
