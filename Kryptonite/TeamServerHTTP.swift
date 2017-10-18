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

}
