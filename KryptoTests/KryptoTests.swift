//
//  KryptoTests.swift
//  KryptoTests
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import XCTest
@testable import Kryptonite
import Sodium

class KryptoTests: XCTestCase {
    
    var keypairClasses:[KeyPair.Type] = [RSAKeyPair.self, Ed25519KeyPair.self]
    var publicKeyClasses:[PublicKey.Type] = [RSAPublicKey.self, Sign.PublicKey.self]
    var digestTypes:[[DigestType]] = [[.sha1, .sha256, .sha512], [.ed25519]]

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    

    func testGen() {
        for KPClass in keypairClasses {
            log("running test for \(KPClass)")
            
            do {
                try KPClass.destroy("test")
                let _ = try KPClass.generate("test")
                
            } catch (let e) {
                if let ce = e as? CryptoError {
                    XCTFail("test failed: \(ce.getError())")
                } else {
                    XCTFail(e.localizedDescription)
                }
            }

        }
    }
    
    func testLoad() {
        for KPClass in keypairClasses {
            log("running test for \(KPClass)")

            do {
                
                try KPClass.destroy("test")
                let _ = try KPClass.generate("test")
                guard let _ = try KPClass.load("test")
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
    }
    
    func testGenDestroy() {
        
        for KPClass in keypairClasses {
            log("running test for \(KPClass)")

            do {
                try KPClass.destroy("test")
                let _ = try KPClass.generate("test")
                
                try KPClass.destroy("test")
                let lkp = try KPClass.load("test")
                
                XCTAssert(lkp == nil, "destroying keypair failed")
                
            } catch (let e) {
                if let ce = e as? CryptoError {
                    XCTFail("test failed: \(ce.getError())")
                } else {
                    XCTFail(e.localizedDescription)
                }
            }

        }
    }
    
    
    func testGenSignVerify() {
        
        for (index, KPClass) in keypairClasses.enumerated() {
            
            for digestType in digestTypes[index] {
                log("running test for: \(KPClass), using digest algorithm: \(digestType)")

                do {
                    try KPClass.destroy("test")
                    let kp = try KPClass.generate("test")
                    let sig = try kp.sign(data: "hellllo".data(using: String.Encoding.utf8)!, digestType: digestType)
                    
                    let resYes = try kp.publicKey.verify("hellllo".data(using: String.Encoding.utf8)!, signature: sig, digestType:  digestType)
                    XCTAssert(resYes, "sig is supposed to be correct!")
                    
                    let resNo = try kp.publicKey.verify("byyyye".data(using: String.Encoding.utf8)!, signature: sig, digestType:  digestType)
                    XCTAssert(!resNo, "sig is supposed to be wrong!")
                    
                } catch (let e) {
                    if let ce = e as? CryptoError {
                        XCTFail("test failed: \(ce.getError())")
                    } else {
                        XCTFail(e.localizedDescription)
                    }
                }
            }
        }
    }
    
    
    
    
    func testLoadSignVerify() {
        
        for (index, KPClass) in keypairClasses.enumerated() {
            
            for digestType in digestTypes[index] {
                log("running test for: \(KPClass), using digest algorithm: \(digestType)")

                do {
                    try KPClass.destroy("test")
                    let _ = try KPClass.generate("test")
                    
                    guard let loadedKp = try KPClass.load("test")
                        else {
                            XCTFail("test failed: no KeyPair loaded")
                            return
                    }
                    
                    let sig = try loadedKp.sign(data: "hellllo".data(using: String.Encoding.utf8)!, digestType: digestType)
                    let resYes = try loadedKp.publicKey.verify("hellllo".data(using: String.Encoding.utf8)!, signature: sig, digestType:  digestType)
                    
                    XCTAssert(resYes, "sig is supposed to be correct!")
                    
                } catch (let e) {
                    if let ce = e as? CryptoError {
                        XCTFail("test failed: \(ce.getError())")
                    } else {
                        XCTFail(e.localizedDescription)
                    }
                }
            }
        }
    }
    
    func testPublicKeyExport() {

        for KPClass in keypairClasses {
            log("running test for \(KPClass)")

            do {
                try KPClass.destroy("test")
                let kp = try KPClass.generate("test")
                
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
    }
    
    
    func testGenSignExportVerify() {
        
        for (index, KPClass) in keypairClasses.enumerated() {
            let PKClass = publicKeyClasses[index]

            for digestType in digestTypes[index] {
                log("running test for: \(KPClass), using digest algorithm: \(digestType)")

                do {
                    try KPClass.destroy("test")
                    let kp = try KPClass.generate("test")
                    let sig = try kp.sign(data: "hellllo".data(using: String.Encoding.utf8)!, digestType: digestType)
                    
                    let pub = try kp.publicKey.export()
                    let impPubKey = try PKClass.importFrom("test", publicKeyRaw: pub)
                    
                    let resYes = try impPubKey.verify("hellllo".data(using: String.Encoding.utf8)!, signature: sig, digestType:  digestType)
                    XCTAssert(resYes, "sig is supposed to be correct!")
                    
                    let resNo = try impPubKey.verify("byyyye".data(using: String.Encoding.utf8)!, signature: sig, digestType: digestType)
                    XCTAssert(!resNo, "sig is supposed to be wrong!")
                    
                } catch (let e) {
                    if let ce = e as? CryptoError {
                        XCTFail("test failed: \(ce.getError())")
                    } else {
                        XCTFail(e.localizedDescription)
                    }
                }
            }
        }
    }
    
    
    func testPublicKeyExportImport() {
        
        for (index, KPClass) in keypairClasses.enumerated() {
            log("running test for \(KPClass)")
            let PKClass = publicKeyClasses[index]

            do {
                try KPClass.destroy("test")
                let kp = try KPClass.generate("test")
                
                let pub = try kp.publicKey.export()
                let pub2 = try PKClass.importFrom("test", publicKeyRaw: pub)
                
                let pub2secp = try pub2.export().toBase64()
                XCTAssert(pub.toBase64() == pub2secp, "public keys don't match after import export")
                
            } catch (let e) {
                if let ce = e as? CryptoError {
                    XCTFail("test failed: \(ce.getError())")
                } else {
                    XCTFail(e.localizedDescription)
                }
            }

        }
    }
    
    
    func testImportRSAPublicKeyDER() {
        
        do {
            
            try RSAKeyPair.destroy("test")

            let pkRSA = "MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0fAZp+DuQKltrL5b0NPY9awpDVbg4aEedPKsAGReE1d/m96OvlswV5WOjd9sz7Qr0q1WxM+LHbIiORRLrEunHaSdkICVWc7SLV8LI/vsxIs+x8w/2llreutAVFBwhU5I4SK9bFdlDu1BTxQi83oRiM2oECqOZd34qCww16TmnSCLKUeRDigB4bSwgav807BB+wDi5Pg6FneI41XyQY+TaMtEm+h3fxnE+J+2XlG4tuwAv7n2N4lN2gsl2b1PITtQgzeeHRjpDKFVfhUApacCIu3Ia8kaQXDKC6zCBCk8pbWcLtrp35a8G/WPqgxvvVsGrWHmY1gtTwVhOYk5AtkaUjGudWspoTRO5lB59IGNhsr4xcSwK/SbxgYelB/Lj7GLIuxUZLwRZm+jjK7BlKg5883YrwZmTg5BFcjOLw7phbygrPyf7HzUMFyZaBr5dLN5m5nzUs1lxIY/moRkmcZKsxPOfh2DO91kdess7U6/wXowfB3OS1jme2cpefX8pTfxfVLZJxf7Qpll6PZLpMyg5zLnEIkvzwicHK0CJeA94p6eaXtO53li3psrYRvRrxAS5TkyHOR6//EOfxsBLol7jHpAkMEN6ljs9uivSEH/TYW+itde10StIZ36IXmJsHvDEi6AqM01QGz4aI55V9zLk7GkiJOVh3IueAuAvlt7syMCAwEAAQ=="
            
            let _ = try RSAPublicKey.importFrom("test", publicKeyDER: pkRSA)
            
        } catch (let e) {
            if let ce = e as? CryptoError {
                XCTFail("test failed: \(ce.getError())")
            } else {
                XCTFail(e.localizedDescription)
            }
        }
        
        
    }
    
}
