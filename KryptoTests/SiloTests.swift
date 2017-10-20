//
//  SiloTests.swift
//  SiloTests
//
//  Created by Kevin King on 4/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Kryptonite

import UIKit

class SiloTests: XCTestCase {

    override func setUp() {
        super.setUp()
        if !KeyManager.hasKey() {
            try! KeyManager.generateKeyPair(type: .RSA)
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testNeverPaired() {
        do {
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)


            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .noOp)
            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
            XCTFail("expected exception")
        } catch let e {
            guard let _ = e as? SessionRemovedError else {
                XCTFail("\(e)")
                return
            }
        }
    }

    func testPaired() {
        do {
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)

            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .noOp)
            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testUnpaired() {
        do {
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)

            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .noOp)
            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)

            SessionManager.shared.remove(session: session)

            do {
                try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
                XCTFail("expected exception")
            } catch let e {
                guard let _ = e as? SessionRemovedError else {
                    XCTFail("\(e)")
                    return
                }
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testPendingRequest() {
        do {
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: fp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)

            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
            do {
                try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
                XCTFail("expected exception")
            } catch Silo.Errors.requestPending {
            } catch {
                XCTFail("got request pending")
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testOldRequest() {
        do {
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: fp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970 - Properties.requestTimeTolerance * 3), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)
            Policy.set(needsUserApproval: false, for: session)

            do {
                try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
                XCTFail("expected exception")
            } catch Silo.Errors.invalidRequestTime {
            } catch {
                XCTFail("got invalid request time")
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testFutureRequest() {
        do {
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: fp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970 + Properties.requestTimeTolerance * 3), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)
            Policy.set(needsUserApproval: false, for: session)

            do {
                try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
                XCTFail("expected exception")
            }  catch Silo.Errors.invalidRequestTime {
            } catch {
                XCTFail("got invalid request time")
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testValidKey() {
        do {
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: fp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)
            Policy.set(needsUserApproval: false, for: session)

            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testValidKeyTwice() {
        do {
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: fp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)
            Policy.set(manualUnknownHostApprovals: false, for: session)
            Policy.set(needsUserApproval: false, for: session)

            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testInvalidKey() {
        do {
            let randomFp = try Data.random(size: 32).toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: randomFp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)

            SessionManager.shared.add(session: session, temporary: true)
            Policy.set(manualUnknownHostApprovals: false, for: session)
            Policy.set(needsUserApproval: false, for: session)

            do {
                try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
                XCTFail("expected exception")
            } catch let e {
                guard let _ = e as? KeyManager.Errors else {
                    XCTFail("\(e)")
                    return
                }
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testManualUnknownHostApprovalRequired() {
        do {
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let data = try "AAAAIFrZQlwF8k3UCrkwZ2E0U+qGx57wehv5ABkHJStoOCc3MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh".fromBase64()
            let sign = try SignRequest(data: data, fingerprint: fp, hostAuth: nil)
            let request = try Request(id: Data.random(size: 16).toBase64(), unixSeconds: Int(Date().timeIntervalSince1970), sendACK: false, version: Properties.currentVersion, body: .ssh(sign))
            let pairing = try Pairing(name: "test", workstationPublicKey: KRSodium.instance().box.keyPair()!.publicKey)
            let session = try Session(pairing: pairing)
            
            SessionManager.shared.add(session: session, temporary: true)
            
            Policy.set(needsUserApproval: false, for: session)
            
            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
            try Silo.shared.handle(request: request, session: session, communicationMedium: .remoteNotification)
            XCTFail("expected RequestPendingError")

        }  catch Silo.Errors.requestPending {
        } catch {
            XCTFail("got request pending")
        }
    }
}
