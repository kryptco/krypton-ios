//
//  PrintSigchains.swift
//  SigchainTests
//
//  Created by Alex Grinman on 2/23/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import XCTest
@testable import Krypton
import JSON

class PrintSigchains: XCTestCase {
    
    let publicKeyPlaceholder = Data(bytes: [0x01, 0x01, 0x01])
    let signaturePlaceholder = Data(bytes: [0x02, 0x02, 0x02])
    let sshPlaceholder = Data(bytes: [0x03, 0x03, 0x03])
    let pgpPlaceholder = Data(bytes: [0x04, 0x04, 0x04])
    
    func identity(for email:String) -> SigChain.Identity {
        return SigChain.Identity(publicKey: publicKeyPlaceholder.bytes,
                          encryptionPublicKey: publicKeyPlaceholder.bytes,
                          email: email,
                          sshPublicKey: sshPlaceholder,
                          pgpPublicKey: pgpPlaceholder)
    }

    func header() -> SigChain.Header {
        sleep(2)
        return SigChain.Header(utcTime: SigChain.UTCTime(Date().timeIntervalSince1970), protocolVersion: Version(major: 1, minor: 0, patch: 0))
    }
    
    func testPrintFakeSigchainJSON() {
        let teamName = "acme"
        let emails = ["alice@acme.co", "bob@acme.co", "charles@acme.co"]
        
        let create = SigChain.Body.main(.create(SigChain.GenesisBlock(creator: identity(for: emails[0]), teamInfo: SigChain.TeamInfo(name: teamName))))

        let operations:[SigChain.Operation] = [
            SigChain.Operation.setPolicy(SigChain.Policy(temporaryApprovalSeconds: 60*60*5)),
            SigChain.Operation.invite(try! .indirect(SigChain.IndirectInvitation(noncePublicKey: Data.random(size: 32).bytes,
                                                                            inviteSymmetricKeyHash: Data.random(size: 32),
                                                                            inviteCiphertext: Data.random(size: 64),
                                                                            restriction: .domain("acme.co")))),
            SigChain.Operation.acceptInvite(identity(for: emails[2])),
            SigChain.Operation.promote(publicKeyPlaceholder.bytes),
        ]


        let appends = operations.map {  try! SigChain.Body.main(.append(SigChain.Block(lastBlockHash: Data.random(size: 32), operation: $0))) }
        
        var messages:[SigChain.Message] = [SigChain.Message(header: header(), body: create)]
        
        appends.forEach {
            messages.append(SigChain.Message(header: header(), body: $0))
        }
        
        let signedMessages:[Object] = messages.map { ["public_key": publicKeyPlaceholder.toBase64(),
                                                      "message": $0.object,
                                                      "signature": signaturePlaceholder.toBase64()]}
        
       var json = try! JSON.jsonString(for: ["sigchain": signedMessages], prettyPrinted: true)
        
        for string in [publicKeyPlaceholder, signaturePlaceholder] {
            json = json.replacingOccurrences(of: string.toBase64(), with: "...")
        }
        json = json.replacingOccurrences(of: sshPlaceholder.toBase64(), with: "ssh-rsa AAAA...")
        json = json.replacingOccurrences(of: pgpPlaceholder.toBase64(), with: "----- BEGIN PGP PUBLIC KEY -----...")
        
        print(json)
    }
}
 
