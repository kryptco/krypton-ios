//
//  TeamServerHTTP.swift
//  Krypton
//
//  Created by Alex Grinman on 8/28/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import SwiftHTTP
import JSON


class TeamServerHTTP:TeamServiceAPI {
    
    // set the TeamService request timeout interval
    init() {
        HTTP.globalRequest { request in
            request.timeoutInterval = 10.0
        }
    }
    
    private func endpointURL(for endpoint:TeamService.Endpoint) -> String {
        return "\(Properties.transport)://\(Properties.teamsServerEndpoints().apiHost)/\(endpoint.rawValue)"
    }

    /**
     Send a JSON object to the team server using HTTP PUT
     */
    func send<T>(object:Object, for endpoint:TeamService.Endpoint, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void) {
        
        log("[ team server ] send (sync) /\(endpoint.rawValue)\nobject: \(object)")

        HTTP.PUT(endpointURL(for: endpoint), parameters: object, requestSerializer: JSONParameterSerializer())
        { response in
            
            if let err = response.error {
                onCompletion(.error(.connection(err.localizedDescription)))
                return
            }
            
            do {
                let serverResponse = try TeamService.ServerResponse<T>(jsonData: response.data)
                log("[ receive ]\nresponse: \(serverResponse)")
                
                onCompletion(serverResponse)
            } catch {
                let responseString = (try? response.data.utf8String()) ?? "\(response.data.count) bytes"
                onCompletion(.error(.unknown("unexpected response, \(responseString)")))
            }

        }
    }
    
    /**
     *Synchronously* send a JSON object to the team server using HTTP PUT
     */
    func sendSync<T>(object:Object, for endpoint:TeamService.Endpoint) -> TeamService.ServerResponse<T> {
        
        log("[ team server ] send (sync) /\(endpoint.rawValue)\nobject: \(object)")

        let syncMutex = Mutex()
        
        // thread lock
        syncMutex.lock()

        var serverResponse:TeamService.ServerResponse<T>?
                
        HTTP.PUT(endpointURL(for: endpoint), parameters: object, requestSerializer: JSONParameterSerializer())
        { response in
            
            if let err = response.error {
                serverResponse = .error(.connection(err.localizedDescription))
                syncMutex.unlock() // release thread lock
                return
            }

            do {
                let theServerResponse = try TeamService.ServerResponse<T>(jsonData: response.data)
                log("[ receive ]\nresponse: \(theServerResponse)")

                serverResponse = theServerResponse
            } catch {
                log("error parsing server response: \(error)", .error)
                let responseString = (try? response.data.utf8String()) ?? "\(response.data.count) bytes"
                serverResponse = .error(.unknown("unexpected response, \(responseString)"))
            }
            
            syncMutex.unlock() // release thread lock

        }
        
        syncMutex.lock()
        defer { syncMutex.unlock() }
        
        return serverResponse ?? .error(.connection("fatal error no response"))
        
    }


}
