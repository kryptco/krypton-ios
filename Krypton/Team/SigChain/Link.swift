//
//  InviteLink.swift
//  Krypton
//
//  Created by Alex Grinman on 11/29/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension SigChain {
    struct JoinTeamInvite {
        let symmetricKey:SodiumSecretBoxKey
        
        enum Errors:Error {
            case invalidPath
        }
        
        init(symmetricKey:SodiumSecretBoxKey) {
            self.symmetricKey = symmetricKey
        }
        
        init(path:[String]) throws {
            guard path.count == 1 else {
                throw Errors.invalidPath
            }
            
            let key = try path[0].fromBase64().bytes
            
            self = JoinTeamInvite(symmetricKey: key)
        }
        
        var path:[String] {
            return [symmetricKey.data.toBase64(true)]
        }
    }
    enum Link {
        case invite(JoinTeamInvite)
        
        enum Path:String {
            case invite = "join_team"
        }
        
        func string(for scheme:String) -> String {
            switch self {
            case .invite(let teamInvite):
                let path = Path.invite.rawValue
                return "\(scheme)\(path)/" + teamInvite.path.joined(separator: "/")
            }
        }
    }

}

