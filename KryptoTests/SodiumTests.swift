//
//  SodiumTests.swift
//  Kryptonite
//
//  Created by Kevin King on 9/20/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import XCTest
@testable import Kryptonite

import Sodium


class SodiumTests: XCTestCase {

    var sodium: Sodium?
    override func setUp() {
        super.setUp()
        sodium = Sodium()
    }

    override func tearDown() {
        super.tearDown()
    }


    func testSodiumAnonymousSealToSelf() {
        guard let sodium = sodium else {
            XCTFail()
            return
        }
        let box = sodium.box
        let ptxt = Data([0,0,1])
        guard let kp: Box.KeyPair = box.keyPair() else {
            XCTFail()
            return
        }

        log("pk length \(kp.publicKey.count)")

        
        guard let sealed = box.seal(message: ptxt, recipientPublicKey: kp.publicKey) else {
            XCTFail()
            return
        }

        log("ctxt length \(sealed.count)")
        
        guard let opened = box.open(anonymousCipherText: sealed, recipientPublicKey: kp.publicKey, recipientSecretKey: kp.secretKey) else {
            XCTFail()
            return
        }

        XCTAssert(opened == ptxt)

    }
}
