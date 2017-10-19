//
//  TeamServerHTTP.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/28/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import SwiftHTTP
import JSON

class TeamServerHTTP:TeamServiceAPI {
    /**
        Send a JSON object to the teams service and parse the response as a ServerResponse
     */
    func sendRequest<T>(object:Object, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void) {
        
        log("[IN] SigChainSVC\n\t\(object)")

        HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object, requestSerializer: JSONParameterSerializer())
        { response in
            do {
                if let err = response.error {
                    throw err
                }
                
                let serverResponse = try TeamService.ServerResponse<T>(jsonData: response.data)
                log("[OUT] SigChainSVC\n\t\(serverResponse)")
                
                onCompletion(serverResponse)
            } catch {
                let responseString = (try? response.data.utf8String()) ?? "\(response.data.count) bytes"
                onCompletion(TeamService.ServerResponse.error(TeamService.ServerError(message: "unexpected response, \(responseString)")))
            }

        }
        
        
    }
    
    /**
         Send a JSON object to the teams service *synchronously& and parse the response as a ServerResponse
     */
    func sendRequestSynchronously<T>(object:Object) -> TeamService.ServerResponse<T> {
        
        log("[IN] SigChainSVC\n\t\(object)")
        
        let syncMutex = Mutex()
        
        // thread lock
        syncMutex.lock()

        var serverResponse:TeamService.ServerResponse<T>?
        
        HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object, requestSerializer: JSONParameterSerializer())
        { response in
            do {
                if let err = response.error {
                    throw err
                }
                
                let theServerResponse = try TeamService.ServerResponse<T>(jsonData: response.data)
                log("[OUT] SigChainSVC\n\t\(theServerResponse)")
                
                serverResponse = theServerResponse
                syncMutex.unlock() // release thread lock
                
            } catch {
                let responseString = (try? response.data.utf8String()) ?? "\(response.data.count) bytes"
                serverResponse = TeamService.ServerResponse.error(TeamService.ServerError(message: "unexpected response, \(responseString)"))
                syncMutex.unlock() // release thread lock
            }
        }
        
        syncMutex.lock()
        
        let finalResponse = serverResponse ?? TeamService.ServerResponse.error(TeamService.ServerError(message: "fatal error no response"))
        
        syncMutex.unlock()
        return finalResponse
        
    }


}
