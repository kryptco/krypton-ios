//
//  Describe.swift
//  Krypton
//
//  Created by Alex Grinman on 11/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension SigChain.Policy {
    var description:String {
        if let approvalSeconds = temporaryApprovalSeconds {
            return TimeInterval(approvalSeconds).timeAgoLong(suffix: "")
        } else {
            return "unset"
        }
    }

}

extension SigChain.LoggingEndpoint {
    var displayDescription:String {
        switch self {
        case .commandEncrypted:
            return "Encrypted"
        }
    }
}
