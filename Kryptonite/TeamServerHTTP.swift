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
    func sendRequest<T:JsonReadable>(object:Object, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void) throws {
        let req = try HTTP.PUT(Properties.TeamsEndpoint.dev.rawValue, parameters: object, requestSerializer: JSONParameterSerializer())
        
        log("[IN] HashChainSVC\n\t\(object)")
        
        req.start { response in
            do {
                let serverResponse = try TeamService.ServerResponse<T>(jsonData: response.data)
                log("[OUT] HashChainSVC\n\t\(serverResponse)")
                
                onCompletion(serverResponse)
            } catch {
                let responseString = (try? response.data.utf8String()) ?? "\(response.data.count) bytes"
                onCompletion(TeamService.ServerResponse.error(TeamService.ServerError(message: "unexpected response, \(responseString)")))
            }
        }
    }

}
