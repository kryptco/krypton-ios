//
//  TeamService+EmailChallenge.swift
//  Krypton
//
//  Created by Alex Grinman on 1/18/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

// Email Challenges: Send + Verify

extension TeamService {
    func sendEmailChallenge(for email:String, _ completionHandler:@escaping (TeamServiceResult<Bool>) -> Void) {
        server.send(object: ["email": email], for: .sendEmailChallenge) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success:
                completionHandler(TeamServiceResult.result(true))
            }
        }
    }
    
    func verifyEmail(with challenge:SigChain.EmailChallenge, _ completionHandler:@escaping (TeamServiceResult<Bool>) -> Void) throws {
        let signedMessage = try self.teamIdentity.sign(body: .emailChallenge(challenge))
        
        server.send(object: signedMessage.object, for: .verifyEmail) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success:
                completionHandler(TeamServiceResult.result(true))
            }
        }
    }

}
