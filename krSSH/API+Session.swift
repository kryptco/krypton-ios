//
//  API+Session.swift
//  krSSH
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

extension API {
    
    func receive(with:Pairing)  {
        receive(with.queue) { (result) in
            switch result {
            case .message(let msgs):
                for msg in msgs {
                    
                    do {
                        let req = try Request(key: with.key, sealed: msg)
                        let resp = try Silo.handle(request: req).seal(key: with.key)
                        
                        self.send(to: with.queue, message: resp, handler: { (sendResult) in
                            switch sendResult {
                            case .sent:
                                log("success! sent response.")
                            case .failure(let e):
                                log("error sending response: \(e)", LogType.error)
                            default:
                                break
                            }
                        })
                    } catch (let e) {
                        log("error responding: \(e)", LogType.error)
                    }
                }
                break
            case .sent:
                log("sent")
            case .failure(let e):
                log("error recieving: \(e)", LogType.error)
            }
        }
    }

}
