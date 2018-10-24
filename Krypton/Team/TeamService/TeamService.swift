//
//  TeamService.swift
//  Krypton
//
//  Created by Alex Grinman on 8/1/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON
import SwiftHTTP

protocol TeamServiceAPI {
    func send<T>(object:Object, for endpoint:TeamService.Endpoint, _ onCompletion:@escaping (TeamService.ServerResponse<T>) -> Void)
    func sendSync<T>(object:Object, for endpoint:TeamService.Endpoint) -> TeamService.ServerResponse<T>
}

class TeamService {

    // static instance
    static var instance:TeamService? = nil
    static let mutex = Mutex()
    
    class func shared() throws -> TeamService {
        defer { mutex.unlock() }
        mutex.lock()
        
        guard let teamIdentity = try IdentityManager.getTeamIdentity() else {
            throw Errors.noTeam
        }
        
        guard let i = instance else {
            instance = TeamService(teamIdentity: teamIdentity, mutex: mutex)
            return instance!
        }
        
        i.teamIdentity = teamIdentity
        
        return i
    }
    
    class func temporary(for teamIdentity:TeamIdentity, server:TeamServiceAPI = TeamServerHTTP()) -> TeamService {
        return TeamService(teamIdentity: teamIdentity, mutex: Mutex(), server: server)
    }

    enum Endpoint:String {
        case sigChain = "sig_chain"
        case sendEmailChallenge = "send_email_challenge"
        case verifyEmail = "verify_email"
        case inviteCiphertext = "invite_link_ciphertext"
        case pushSubscription = "push_subscription"
        case billingInfo = "billing_info"
    }
    
    enum Errors:Error {
        case noTeam
        
        case badResponse
        case badInviteSeed
        
        case payloadSignature
        case needNewestBlock
        case checkpointNotReached
        
        case missingLastBlockHash
        
        case needAdminKeypair
        case errorResponse(ServerError)
        
        case blockDidNotPost
    }
    
    enum ServerError:Error, CustomDebugStringConvertible {
        
        case known(KnownServerErrorMessage)
        case unknown(String)
        case connection(String)
        
        enum KnownServerErrorMessage:String {
            case unspecifiedError = "unspecified error"
            case notAppendingToMainChain = "NotAppendingToMainChain"
            case databaseTransactionRollback = "DatabaseTransactionRollback"
            case freeTierLimitReached = "FreeTierLimitReached"
            
            var humanReadableError:String {
                switch self {
                case .notAppendingToMainChain, .databaseTransactionRollback:
                    return "Not appending to the main chain, need to fetch new blocks"
                case .unspecifiedError:
                    return "Server error not specified"
                case .freeTierLimitReached:
                    return "You have reached the limit of the free tier. Please upgrade to Krypton Teams Pro for unlimited team members, real-time audit logs, and pinned server hosts. Please contact your team admin to upgrade."
                }
            }
        }
        
        init(message:String) {
            guard let knownError = KnownServerErrorMessage(rawValue: message) else {
                self = .unknown(message)
                return
            }
            
            self = .known(knownError)
        }
        
        var isNotAppendingToMainChain:Bool {
            switch self {
            case .known(let knownError):
                switch knownError {
                case .notAppendingToMainChain, .databaseTransactionRollback:
                    return true
                default:
                    break
                }
            default:
                break
            }
            
            return false
        }
        
        var debugDescription: String {
            switch self {
            case .known(let knownError):
                return knownError.humanReadableError
            case .unknown(let message):
                return "Unknown error from server: \(message)"
            case .connection(let message):
                return "Couldn't connect to server: \(message)"
            }
        }
    }
    
    enum ServerResponse<T:JsonReadable>:JsonReadable, CustomDebugStringConvertible {
        case error(ServerError)
        case success(T)
        
        init(json: Object) throws {
            if let success:Object = try? json ~> "success" {
                self = try .success(T(json: success))
            } else if let message:String = try? json ~> "error" {
                self = .error(ServerError(message: message))
            } else {
                throw Errors.badResponse
            }
        }
        
        var debugDescription: String {
            switch self {
            case .success(let obj):
                return "SUCCESS:\n\t\t- \(obj)"
            case .error(let error):
                return "FAILURE:\n\t\t- \(error)"
            }
        }
    }
    
    enum TeamServiceResult<T> {
        case result(T)
        case error(Error)
    }
    
    struct EmptyResponse:JsonReadable {
        init() {}
        init(json: Object) throws {}
    }

    var teamIdentity:TeamIdentity
    var mutex:Mutex
    var server:TeamServiceAPI
    
    // retry constant
    private static let mainChainRetryCount:Int = 3
    
    private init(teamIdentity:TeamIdentity, mutex:Mutex, server:TeamServiceAPI = TeamServerHTTP()) {
        self.teamIdentity = teamIdentity
        self.mutex = mutex
        self.server = server
    }
    
    //MARK: Joining a team: Create, Accept Invites: Indirect, Direct
    
    /**
        Create a team and add the admin, thereby starting a new chain 
        with the admin as the first team member
     */
    func createTeam(signedMessage:SigChain.SignedMessage, _ completionHandler:@escaping (TeamServiceResult<TeamService>) -> Void) throws {
        mutex.lock()
        
        // send the payload signedMessage
        server.send(object: signedMessage.object, for: .sigChain) { (serverResponse:ServerResponse<EmptyResponse>) in
            defer { self.mutex.unlock() }
            
            switch serverResponse {
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))

            case .success:
                completionHandler(TeamServiceResult.result(self))
            }
        }
    }
    
    
    /**
        Write an append block accepting a team invitation
        Special case: the team invitation keypair is used to sign the payload
     */
    func acceptSync(invite:SigChain.IndirectInvitation.Secret, retry:Int = TeamService.mainChainRetryCount) throws -> TeamServiceResult<TeamService> {
        mutex.lock()
        defer { mutex.unlock() }

        return try teamIdentity.dataManager.withTransaction{ return try self.acceptSyncUnlocked(invite: invite, retry: retry, dataManager: $0) }
    }

    internal func acceptSyncUnlocked(invite:SigChain.IndirectInvitation.Secret, retry:Int = TeamService.mainChainRetryCount, dataManager:TeamDataManager) throws -> TeamServiceResult<TeamService> {
        
        let keyManager = try KeyManager.sharedInstance()
        
        let newMember = try SigChain.Identity(publicKey: teamIdentity.publicKey,
                                          encryptionPublicKey: teamIdentity.encryptionPublicKey,
                                          email: teamIdentity.email,
                                          sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                          pgpPublicKey: keyManager.loadPGPPublicKey(for: teamIdentity.email).packetData)
        
        // use the invite `seed` to create a nonce sodium keypair
        guard let nonceKeypair = KRSodium.instance().sign.keyPair(seed: invite.nonceKeypairSeed.bytes) else {
            throw Errors.badInviteSeed
        }
        
        // get current block hash
        guard let blockHash = try dataManager.lastBlockHash() else {
            throw Errors.needNewestBlock
        }
        
        // create the message
        let acceptBlock = SigChain.Block(lastBlockHash: blockHash, operation: .acceptInvite(newMember))
        let message = SigChain.Message(body: .main(.append(acceptBlock)))
        let messageData = try message.jsonData()
        
        // sign the payload json
        // Note: in this special case the nonce key pair is used to sign the payload
        
        guard let signature = KRSodium.instance().sign.signature(message: messageData.bytes, secretKey: nonceKeypair.secretKey)
            else {
                throw Errors.payloadSignature
        }
        
        let serializedString = try messageData.utf8String()
        let signedMessage = SigChain.SignedMessage(publicKey: nonceKeypair.publicKey.data,
                                               message: serializedString,
                                               signature: signature.data)


        
        let serverResponse:ServerResponse<EmptyResponse> = server.sendSync(object: signedMessage.object, for: .sigChain)
        
        switch serverResponse {
        case .error(let error):
            if error.isNotAppendingToMainChain, retry > 0 {
                switch try self.getTeamSyncUnlocked(using: invite, dataManager: dataManager) {
                case .error(let e):
                    return .error(e)
                case .result:
                    return try self.acceptSyncUnlocked(invite: invite, retry: retry - 1, dataManager: dataManager)
                }
            }
            
            return .error(error)
            
        case .success:
            try self.teamIdentity.verifyAndProcessBlocks(response: SigChain.ReadBlocksResponse(blocks: [signedMessage], hasMore: false), dataManager: dataManager)
            return .result(self)
        }
    }
    
    /**
        Write an append block accepting a *direct* team invitation
        Special case: the team keypair is used to sign the payload
     */
    func acceptDirectInvitationSync(retry:Int = TeamService.mainChainRetryCount) throws -> TeamServiceResult<TeamService>  {
        mutex.lock()
        defer { mutex.unlock() }

        return try teamIdentity.dataManager.withTransaction { return try self.acceptDirectInvitationSyncUnlocked(retry: retry, dataManager: $0) }
    }
    
    internal func acceptDirectInvitationSyncUnlocked(retry:Int = TeamService.mainChainRetryCount, dataManager: TeamDataManager) throws -> TeamServiceResult<TeamService> {
        
        let keyManager = try KeyManager.sharedInstance()
        
        let newMember = try SigChain.Identity(publicKey: teamIdentity.publicKey,
                                          encryptionPublicKey: teamIdentity.encryptionPublicKey,
                                          email: teamIdentity.email,
                                          sshPublicKey: keyManager.keyPair.publicKey.wireFormat(),
                                          pgpPublicKey: keyManager.loadPGPPublicKey(for: teamIdentity.email).packetData)
        
        
        guard let lastBlockHash = try dataManager.lastBlockHash() else {
            throw Errors.missingLastBlockHash
        }
        
        let signedMessage = try teamIdentity.sign(operation: .acceptInvite(newMember), lastBlockHash: lastBlockHash)
        
        let serverResponse:ServerResponse<EmptyResponse> = server.sendSync(object: signedMessage.object, for: .sigChain)
        
        switch serverResponse {
            
        case .error(let error):
            if error.isNotAppendingToMainChain, retry > 0 {
                switch try self.getVerifiedTeamUpdatesSyncUnlocked(dataManager: dataManager){
                case .error(let e):
                    return .error(e)
                case .result:
                    return try self.acceptDirectInvitationSyncUnlocked(retry: retry - 1, dataManager: dataManager)
                }
            }

            return .error(error)
            
        case .success:
            try self.teamIdentity.verifyAndProcessBlocks(response: SigChain.ReadBlocksResponse(blocks: [signedMessage], hasMore: false), dataManager: dataManager)
            return .result(self)
        }

        
    }

    //MARK: Append Main Chain Operation Blocks
    func appendToMainChainSync(for requestableOperation:RequestableTeamOperation, retryCount:Int = TeamService.mainChainRetryCount) throws -> (TeamService, TeamOperationResponse)
    {
        mutex.lock()
        defer { mutex.unlock() }
        
        return try teamIdentity.dataManager.withTransaction { return try self.appendToMainChainSyncUnlocked(for: requestableOperation, retryCount: retryCount, dataManager: $0) }
    }
    
    internal func appendToMainChainSyncUnlocked(for requestableOperation:RequestableTeamOperation, retryCount:Int = TeamService.mainChainRetryCount, dataManager:TeamDataManager) throws -> (TeamService, TeamOperationResponse)
    {
        
        let originalMutableData = teamIdentity.mutableData
        
        let (signedMessage, responseData) = try teamIdentity.signedMessage(for: requestableOperation, dataManager: dataManager)
        let response:ServerResponse<EmptyResponse> = server.sendSync(object: signedMessage.object, for: .sigChain)
        
        switch response {
        case .error(let error):
            teamIdentity.mutableData = originalMutableData
            
            if error.isNotAppendingToMainChain, retryCount > 0 {
                
                switch try self.getVerifiedTeamUpdatesSyncUnlocked(dataManager: dataManager) {
                case .error(let fetchError):
                    throw fetchError
                    
                case .result(let service):
                    return try service.appendToMainChainSyncUnlocked(for: requestableOperation,
                                                                     retryCount: retryCount - 1,
                                                                     dataManager: dataManager)
                }
            }
            
            throw error
            
        case .success:
            break
        }
        
        // process the new block we just created and posted
        try self.teamIdentity.verifyAndProcessBlocks(response: SigChain.ReadBlocksResponse(blocks: [signedMessage], hasMore: false), dataManager: dataManager)
        
        // return an `ok` with the team operation response
        return (self, TeamOperationResponse(postedBlockHash: signedMessage.hash(), data: responseData))
    }
    
    
    // MARK: Fetch full invite ciphertext and decrypt it
    static func fetchFullTeamInvite(for partialInvite:SigChain.JoinTeamInvite, server:TeamServiceAPI = TeamServerHTTP(), _ completionHandler:@escaping (TeamServiceResult<SigChain.IndirectInvitation.Secret>) -> Void) {
        
        let symmetricKeyHash = partialInvite.symmetricKey.SHA256.toBase64()
        
        struct InviteLinkCiphertextResponse:JsonReadable {
            let ciphertext:Data
            
            enum Errors:Error {
                case badCiphertext
            }
            
            init(json: Object) throws {
                ciphertext = try ((json ~> "ciphertext") as String).fromBase64()
            }
        }
        
        server.send(object: ["symmetric_key_hash": symmetricKeyHash], for: .inviteCiphertext) { (serverResponse:ServerResponse<InviteLinkCiphertextResponse>) in
            switch serverResponse {
                
            case .error(let error):
                completionHandler(TeamServiceResult.error(error))
                
            case .success(let inviteCiphertext):
                do {
                    guard let inviteJson:[UInt8] = KRSodium.instance().secretBox.open(nonceAndAuthenticatedCipherText: inviteCiphertext.ciphertext.bytes, secretKey: partialInvite.symmetricKey)
                    else {
                        throw InviteLinkCiphertextResponse.Errors.badCiphertext
                    }
                    
                    let invite = try SigChain.IndirectInvitation.Secret(jsonData: inviteJson.data)
                    completionHandler(TeamServiceResult.result(invite))
                } catch {
                    completionHandler(TeamServiceResult.error(error))
                }
                
            }
        }
    }
    
}


/// TeamIdentity + TeamPointer
extension TeamIdentity {
    func teamPointer(dataManager: TeamDataManager) throws -> SigChain.TeamPointer {
        if let blockHash = try dataManager.lastBlockHash() {
            return SigChain.TeamPointer.lastBlockHash(blockHash)
        }
        
        return SigChain.TeamPointer.publicKey(self.initialTeamPublicKey)
    }
}



