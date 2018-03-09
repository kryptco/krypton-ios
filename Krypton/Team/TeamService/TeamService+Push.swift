//
//  TeamService+Push.swift
//  Krypton
//
//  Created by Alex Grinman on 1/18/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

// Push Token Subscriptions

extension TeamService {
    func subscribeToPushSync(with token:String) throws {
        let pushDevice = SigChain.PushDevice.thisDevice(with: token)
        
        let pushSubscription = try teamIdentity.dataManager.withTransaction {
            return try SigChain.PushSubscription(teamPointer: self.teamIdentity.teamPointer(dataManager: $0), action: .subscribe(pushDevice))
        }
        
        let signedMessage = try self.teamIdentity.sign(body: .pushSubscription(pushSubscription))
        
        let response:ServerResponse<EmptyResponse> = server.sendSync(object: signedMessage.object, for: .pushSubscription)
        
        switch response {
        case .error(let error):
            throw error
        case .success:
            break
        }
    }
    
    func subscribeToPush(with token:String, _ completionHandler:@escaping (TeamServiceResult<Bool>) -> Void) throws {
        let pushDevice = SigChain.PushDevice.thisDevice(with: token)

        let pushSubscription = try teamIdentity.dataManager.withTransaction {
            return try SigChain.PushSubscription(teamPointer: self.teamIdentity.teamPointer(dataManager: $0), action: .subscribe(pushDevice))
        }
        
        let signedMessage = try self.teamIdentity.sign(body: .pushSubscription(pushSubscription))
        
        server.send(object: signedMessage.object, for: .pushSubscription) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success:
                completionHandler(TeamServiceResult.result(true))
            }
        }
    }
    
    func unsubscribeFromPush(_ completionHandler:@escaping (TeamServiceResult<Bool>) -> Void) throws {
        let pushSubscription = try teamIdentity.dataManager.withTransaction {
            return try SigChain.PushSubscription(teamPointer: self.teamIdentity.teamPointer(dataManager: $0), action: .unsubscribe)
        }

        let signedMessage = try self.teamIdentity.sign(body: .pushSubscription(pushSubscription))
        
        server.send(object: signedMessage.object, for: .pushSubscription) { (serverResponse:ServerResponse<EmptyResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success:
                completionHandler(TeamServiceResult.result(true))
            }
        }
    }

}
