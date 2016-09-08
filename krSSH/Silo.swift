//
//  Silo.swift
//  krSSH
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

class Silo {
    
    class func handle(request:Request) throws -> Response {
        var sign:SignResponse?
        var list:ListResponse?
        var me:MeResponse?

        if let signRequest = request.sign {
            let kp = try KeyManager.sharedInstance()
            
            var sig:String?
            var err:String?
            do {
                sig = try kp.keyPair.sign(signRequest.message)

            } catch let e {
                guard e is CryptoError else {
                    throw e
                }
                
                err = "\(e)"
                throw e
            }
            
            sign = SignResponse(sig: sig, err: err)
        }
        
        if let _ = request.list {
            list = ListResponse(peers: PeerManager.sharedInstance().all)
        }
        if let _ = request.me {
            me = MeResponse(me: try KeyManager.sharedInstance().getMe())
        }
        
        return Response(requestID: request.id, endpoint: "", sign: sign, list: list, me: me)
    }
}
