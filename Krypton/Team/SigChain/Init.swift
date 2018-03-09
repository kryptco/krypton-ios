//
//  Init.swift
//  Krypton
//
//  Created by Alex Grinman on 11/29/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension SigChain.Header {
    static func new() -> SigChain.Header {
        return SigChain.Header(utcTime: SigChain.UTCTime(Date().timeIntervalSince1970), protocolVersion: SigChain.protocolVersion)
    }
}

extension SigChain.Message {
    init(body:SigChain.Body) {
        self.header = SigChain.Header.new()
        self.body = body
    }
}

extension SigChain.PushDevice {
    static func thisDevice(with token:Token) -> SigChain.PushDevice {
        return .iOS(token)
    }
}

extension SigChain.BoxedMessage {
    init(wrappedKey:SigChain.WrappedKey, senderPublicKey:SodiumBoxPublicKey) {
        self.init(recipientPublicKey: wrappedKey.recipientPublicKey,
                  senderPublicKey: senderPublicKey,
                  ciphertext: wrappedKey.ciphertext)
    }
}
