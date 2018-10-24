//
//  Silo.swift
//  Krypton
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON
import AwesomeCache
import PGPFormat

struct UserRejectedError:Error, CustomDebugStringConvertible {
    static let rejectedConstant = "rejected"
    
    var debugDescription:String {
        return UserRejectedError.rejectedConstant
    }
    
    static func isRejected(errorString:String) -> Bool {
        return errorString == rejectedConstant
    }
}


typealias CacheKey = String
extension CacheKey {
    init(_ session:Session, _ request:Request) {
        self = "\(session.id)_\(request.id)"
    }
}

class Silo {
    
    var mutex = Mutex()
    var teamsOperationMutex = Mutex()

    var requestCache: Cache<NSData>
    //  store requests waiting for user approval
    var pendingRequests: Cache<NSString>
    
    // singelton
    private static var sharedSiloMutex = Mutex()
    private static var sharedSilo:Silo?
    
    class func shared() throws -> Silo {
        defer { sharedSiloMutex.unlock() }
        sharedSiloMutex.lock()
        
        guard let ss = sharedSilo else {
            sharedSilo = try Silo()
            return sharedSilo!
        }
        return ss
    }

    enum Errors:Error {
        case invalidRequestTime
        case requestPending
        case responseNotNeeded
        case siloCacheCreation
        case noTeamIdentity
    }
    
    init() throws {
        requestCache = try Cache<NSData>(name: "silo_cache", directory: SecureLocalStorage.directory(for: "silo_cache"))
        pendingRequests = try Cache<NSString>(name: "silo_pending_requests", directory: SecureLocalStorage.directory(for: "silo_pending_requests"))
    }
    
    //MARK: Handle Logic
    func handle(request:Request, session:Session, communicationMedium: CommunicationMedium, completionHandler: (()->Void)? = nil) throws {
        
        // lock based on the request type
        var isTeamOperation:Bool
        switch request.body {
        case .teamOperation:
            isTeamOperation = true
            teamsOperationMutex.lock()
            
        case .me, .ssh, .git, .hosts, .noOp, .unpair, .readTeam, .decryptLog, .u2fAuthenticate, .u2fRegister:
            isTeamOperation = false
            mutex.lock()
        }
        
        defer {
            if isTeamOperation {
                teamsOperationMutex.unlock()
            } else {
                mutex.unlock()
            }
        }

        
        // remove expired request as cleanup
        requestCache.removeExpiredObjects()

        // ensure session is still active
        guard let _ = SessionManager.shared.get(id: session.id) else {
            throw SessionRemovedError()
        }
        
        // ensure request has not expired
        let now = Date().timeIntervalSince1970
        if abs(now - Double(request.unixSeconds)) > Properties.requestTimeTolerance {
            throw Silo.Errors.invalidRequestTime
        }
        
        
        // check if the request has already been received and cached
        if  let cachedResponseData = requestCache[CacheKey(session, request)] as Data? {
            let json:Object = try JSON.parse(data: cachedResponseData)
            let response = try Response(json: json)
            try TransportControl.shared.send(response, for: session, completionHandler: completionHandler)
            return
        }
        
        // ensure request has not expired
        // workaround: check request time again in case cache is slow
        let nowAgain = Date().timeIntervalSince1970
        if abs(nowAgain - Double(request.unixSeconds)) > Properties.requestTimeTolerance {
            throw Silo.Errors.invalidRequestTime
        }
        
        // pre request processing analytics
        if case .ssh(let sshRequest) = request.body, sshRequest.verifiedHostAuth == nil {
            Analytics.postEvent(category: "host", action: "unknown")
        }
        
        // handle special cases
        switch request.body {
        case .unpair:
            Analytics.postEvent(category: "device", action: "unpair", label: "request")
            
            SessionManager.shared.remove(session: session)
            TransportControl.shared.remove(session: session, sendUnpairResponse: false)
            
            throw SessionRemovedError()
            
        case .noOp:
            return
            
        // typical cases
        case .git,
             .ssh,
             .hosts,
             .me,
             .decryptLog,
             .teamOperation,
             .readTeam,
             .u2fRegister,
             .u2fAuthenticate:
            
            break
        }
        
        // decide if request body can be responded to immediately
        let isAllowed = Policy.SessionSettings(for: session).isAllowed(for: request)
        
        guard isAllowed else {
            try handleRequestRequiresApproval(request: request, session: session, communicationMedium: communicationMedium, completionHandler: completionHandler)
            return
        }

        // otherwise, continue with creating and sending the response
        let response = try responseFor(request: request, session: session, allowed: true)
        try TransportControl.shared.send(response, for: session, completionHandler: completionHandler)

        // notify user sent signature or error
        switch response.body {
        case .ssh, .git, .u2fRegister, .u2fAuthenticate:
            if let error = response.body.error {
                Policy.notifyUser(errorMessage: error, request: request, session: session)
            } else {
                Policy.notifyUser(session: session, request: request)
            }
        case .readTeam, .teamOperation, .decryptLog, .me, .ack, .unpair, .hosts:
            break
        }
        
        // analytics
        switch response.body {
        case .ssh, .git, .u2fAuthenticate, .u2fRegister, .decryptLog, .teamOperation, .readTeam:
            Analytics.postEvent(category: request.body.analyticsCategory, action: "automatic approval", label: communicationMedium.rawValue)
            
        case .me, .ack, .unpair, .hosts:
            break
        }
    }

    func handleRequestRequiresApproval(request: Request, session: Session, communicationMedium: CommunicationMedium, completionHandler: (() -> ())?) throws {

        pendingRequests.removeExpiredObjects()
        if pendingRequests.object(forKey: CacheKey(session, request)) != nil {
            throw Silo.Errors.requestPending
        }
        pendingRequests.setObject("", forKey: CacheKey(session, request), expires: .seconds(Properties.requestTimeTolerance * 2))
        
        Policy.addPendingAuthorization(session: session, request: request)
        Policy.requestUserAuthorization(session: session, request: request)
        
        if request.sendACK {
            let arn = API.endpointARN ?? ""
            let ack = Response(requestID: request.id, endpoint: arn, body: .ack(.ok(AckResponse())), trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
            do {
                try TransportControl.shared.send(ack, for: session)
            } catch (let e) {
                log("ack send error \(e)")
            }
        }
        
        Analytics.postEvent(category: request.body.analyticsCategory, action: "requires approval", label:communicationMedium.rawValue)
        completionHandler?()
    }
    
    // MARK: Pending
    func removePending(request:Request, for session:Session) {
        mutex.lock()
        defer { mutex.unlock() }
        
        pendingRequests.removeObject(forKey: CacheKey(session, request))
    }
    
    func isPending(request:Request, for session:Session) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        
        pendingRequests.removeExpiredObjects()
        if pendingRequests.object(forKey: CacheKey(session, request)) != nil {
            return true
        }
        
        return false
    }

    
    // MARK: Response
    
    func lockResponseFor(request:Request, session:Session, allowed:Bool) throws -> Response {
        
        var isTeamOperation:Bool
        switch request.body {
        case .teamOperation:
            teamsOperationMutex.lock()
            isTeamOperation = true

            
        case .me, .ssh, .git, .hosts, .noOp, .unpair, .readTeam, .decryptLog, .u2fAuthenticate, .u2fRegister:
            mutex.lock()
            isTeamOperation = false
        }
        
        defer {
            if isTeamOperation {
                teamsOperationMutex.unlock()
            } else {
                mutex.unlock()
            }
        }
        
        return try responseFor(request: request, session: session, allowed: allowed)
    }
    
    // precondition: `teamsOperationMutex` locked if a TeamOperationRequestBody body, otherwise `mutex` locked
    private func responseFor(request:Request, session:Session, allowed:Bool) throws -> Response {
        let requestStart = Date().timeIntervalSince1970
        defer { log("response took \(Date().timeIntervalSince1970 - requestStart) seconds") }
        
        // the response type
        var responseType:ResponseBody
        var auditLog:Audit.Log?
        
        // craft a response to the request type
        // given the user's approval: `signatureAllowed`
        switch request.body {
        case .ssh(let signRequest):
            var result:ResponseResult<SSHSignResponse>
            var sshAuditLogResult:Audit.SSHSignature.Result

            let kp = try KeyManager.sharedInstance()
            
            if try kp.keyPair.publicKey.fingerprint() != signRequest.fingerprint.fromBase64() {
                throw KeyManager.Errors.keyDoesNotExist
            }

            do {
                guard allowed else {
                    throw UserRejectedError()
                }
                
                
                var hostIsPinnedByTeam = false
                
                // team known hosts
                // if team exists then check for pinned known hosts
                if  let verifiedHostAuth = signRequest.verifiedHostAuth,
                    let teamIdentity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity
                {
                    hostIsPinnedByTeam = try teamIdentity.dataManager.withTransaction {
                        try $0.check(verifiedHost: verifiedHostAuth) // this throws if mismatched
                    }
                }
                
                if !hostIsPinnedByTeam { // check local known hosts if no team information
                    // local known hosts
                    // if host auth provided, check known hosts
                    // fails in invalid signature -or- hostname not provided
                    if let verifiedHostAuth = signRequest.verifiedHostAuth {
                        try KnownHostManager.shared.checkOrAdd(verifiedHostAuth: verifiedHostAuth)
                    }
                }
                
                // only place where signature should occur
                let signature = try kp.keyPair.signAppendingSSHWirePubkeyToPayload(data: signRequest.data, digestType: signRequest.digestType.based(on: request.version))
                
                result = .ok(SSHSignResponse(signature: signature.toBase64()))
                sshAuditLogResult = .signature(signature)

            }
            catch let error as HostMistmatchError {
                result = .error("\(error)")
                sshAuditLogResult = .hostMismatch(error.expectedPublicKeys)
            }
            catch {
                result = .error("\(error)")
                sshAuditLogResult = .error("\(error)")
            }
        
            
            //create the audit log
            let logBody = Audit.LogBody.ssh(Audit.SSHSignature(user: signRequest.user,
                                                               verifiedHostAuth: signRequest.verifiedHostAuth ,
                                                               sessionData: signRequest.session,
                                                               result: sshAuditLogResult))
            
            auditLog = Audit.Log(session: Audit.Session(deviceName: session.pairing.name,
                                                        workstationPublicKeyDoubleHash: session.pairing.workstationPublicKeyDoubleHash),
                                 body: logBody)
            
            // set the response
            responseType = .ssh(result)
            
        
            
        case .git(let gitSignRequest):
            var result:ResponseResult<GitSignResponse>
            var logBody:Audit.LogBody
            
            do {
                guard allowed else {
                    throw UserRejectedError()
                }
                
                // only place where git signature should occur
                let keyManager = try KeyManager.sharedInstance()
                
                let keyID = try keyManager.getPGPPublicKeyID()
                let _ = keyManager.updatePGPUserIDPreferences(for: gitSignRequest.userId)
                
                switch gitSignRequest.git {
                case .commit(let commit):                    
                    let asciiArmoredSig = try keyManager.keyPair.signGitCommit(with: commit, keyID: keyID, comment: Properties.pgpMessageComment(for: request.version))
                    let signature = asciiArmoredSig.packetData
                    result = .ok(GitSignResponse(signature: signature.toBase64()))
                    
                    logBody = .gitCommit(Audit.GitCommitSignature(commitInfo: commit, result: .signature(signature)))
                    
                case .tag(let tag):
                    let asciiArmoredSig = try keyManager.keyPair.signGitTag(with: tag, keyID: keyID, comment: Properties.pgpMessageComment(for: request.version))                    
                    let signature = asciiArmoredSig.packetData
                    result = .ok(GitSignResponse(signature: signature.toBase64()))
                    
                    logBody = .gitTag(Audit.GitTagSignature(tagInfo: tag, result: .signature(signature)))
                }
            }
            catch is UserRejectedError {
                result = .error("\(UserRejectedError())")

                switch gitSignRequest.git {
                case .commit(let commit):
                    logBody = .gitCommit(Audit.GitCommitSignature(commitInfo: commit, result: .userRejected))
                case .tag(let tag):
                    logBody = .gitTag(Audit.GitTagSignature(tagInfo: tag, result: .userRejected))
                }
            }
            catch {
                result = .error("\(error)")
                
                switch gitSignRequest.git {
                case .commit(let commit):
                    logBody = .gitCommit(Audit.GitCommitSignature(commitInfo: commit, result: .error("\(error)")))
                case .tag(let tag):
                    logBody = .gitTag(Audit.GitTagSignature(tagInfo: tag, result: .error("\(error)")))
                }
            }
            
            // create the audit log
            auditLog = Audit.Log(session: Audit.Session(deviceName: session.pairing.name,
                                                        workstationPublicKeyDoubleHash: session.pairing.workstationPublicKeyDoubleHash),
                                 body: logBody)

            // set the response 
            responseType = .git(result)
            
        case .me(let meRequest):
            
            // return a limited resposne for a u2f device
            guard meRequest.u2fOnly == nil || meRequest.u2fOnly == false else {

                let me = MeResponse(me: MeResponse.Me(email: IdentityManager.getMeFallback(),
                                                      publicKeyWire: Data(),
                                                      deviceIdentifier: try U2FDevice.deviceIdentifier(),
                                                      pgpPublicKey: Data(),
                                                      teamCheckpoint: nil,
                                                      u2fAccounts: try U2FAccountManager.getAllKnownAccountsLocked().map({ $0.shortName })))
                responseType = .me(.ok(me))
                break
            }
            
            // return empty if we don't have a key pair
            guard let keyManager:KeyManager = try? KeyManager.sharedInstance() else {
                let me = MeResponse(me: MeResponse.Me(email: IdentityManager.getMeFallback(),
                                                      publicKeyWire: Data(),
                                                      deviceIdentifier: try U2FDevice.deviceIdentifier(),
                                                      pgpPublicKey: Data(),
                                                      teamCheckpoint: nil,
                                                      u2fAccounts: nil))
                responseType = .me(.ok(me))
                break
            }
            
            var pgpPublicKey:Data?
            if let pgpUserID = meRequest.pgpUserId {
                let message = try keyManager.loadPGPPublicKey(for: pgpUserID)
                pgpPublicKey = message.packetData
            }

            var teamCheckpoint:TeamCheckpoint?
            if let identity = try IdentityManager.getTeamIdentity() {
                teamCheckpoint =  TeamCheckpoint(publicKey: identity.publicKey,
                                                 teamPublicKey: identity.initialTeamPublicKey,
                                                 lastBlockHash: identity.checkpoint,
                                                 serverEndpoints: Properties.teamsServerEndpoints())

            }
            
            let me = MeResponse(me: MeResponse.Me(email: IdentityManager.getMeFallback(),
                                                  publicKeyWire: try keyManager.keyPair.publicKey.wireFormat(),
                                                  deviceIdentifier: try U2FDevice.deviceIdentifier(),
                                                  pgpPublicKey: pgpPublicKey,
                                                  teamCheckpoint: teamCheckpoint,
                                                  u2fAccounts: nil))
            responseType = .me(.ok(me))
        
        case .hosts:

            guard allowed else {
                responseType = .hosts(.error("\(UserRejectedError())"))
                break
            }
            
            // git: get the list of PGP user ids
            let pgpUserIDs = try KeyManager.sharedInstance().getPGPUserIDList()
            
            // ssh: read the logs and get a unique set of user@hostnames
            let sshLogs:[SSHSignatureLog] = LogManager.shared.fetchAllSSHUniqueHosts()
            
            var userAndHosts = Set<HostsResponse.UserAndHost>()
            
            sshLogs.forEach({ log in
                guard let (user, host) = log.getUserAndHost() else {
                    return
                }
                
                userAndHosts.insert(HostsResponse.UserAndHost(host: host, user: user))
            })
            
            
            let hostResponse = HostsResponse(pgpUserIDs: pgpUserIDs, hosts: [HostsResponse.UserAndHost](userAndHosts))
            responseType = .hosts(.ok(hostResponse))
            
        case .u2fRegister(let u2fRegisterRequest):
            guard allowed else {
                responseType = .u2fRegister(.error("\(UserRejectedError())"))
                break
            }
            
            let (keypair, keyHandle) = try U2FKeyManager.generate(for: u2fRegisterRequest.appID)
            let publicKey = try keypair.publicKey.export()
            let cert = try keypair.signU2FAttestationCertificate()
            
            let signature = try keypair.signU2FRegistration(application: u2fRegisterRequest.appID.hash,
                                                            keyHandle: keyHandle,
                                                            challenge: u2fRegisterRequest.challenge)
            
            responseType = try .u2fRegister(.ok(U2FRegisterResponse(publicKey: publicKey,
                                                                    keyHandle: keyHandle,
                                                                    attestationCertificate: cert.toDER(),
                                                                    signature: signature)))
            
            try U2FAccountManager.add(account: u2fRegisterRequest.appID)
            
            LogManager.shared.saveGeneric(theLog: U2FLog(session: session.id,
                                                  appID: u2fRegisterRequest.appID,
                                                  isRegister: true,
                                                  signature: signature.toBase64(),
                                                  displayName: session.pairing.displayName), deviceName: session.pairing.displayName)

            
        case .u2fAuthenticate(let u2fAuthRequest):
            guard allowed else {
                responseType = .u2fAuthenticate(.error("\(UserRejectedError())"))
                break
            }
            
            try u2fAuthRequest.keyHandle.validate(for: u2fAuthRequest.appID)
            
            let keypair = try U2FKeyManager.keyPair(for: u2fAuthRequest.keyHandle)
            let publicKey = try keypair.publicKey.export()
            let counter = try U2FKeyManager.fetchAndIncrementCounter(keyHandle: u2fAuthRequest.keyHandle)
            let signature = try keypair.signU2FAuthentication(application: u2fAuthRequest.appID.hash, counter: counter, challenge: u2fAuthRequest.challenge)
            
            responseType = .u2fAuthenticate(.ok(U2FAuthenticateResponse(publicKey: publicKey,
                                                                        counter: counter,
                                                                        signature: signature)))

            try U2FAccountManager.updateLastUsed(account: u2fAuthRequest.appID)
            
            LogManager.shared.saveGeneric(theLog: U2FLog(session: session.id,
                                                  appID: u2fAuthRequest.appID,
                                                  isRegister: false,
                                                  signature: signature.toBase64(),
                                                  displayName: session.pairing.displayName), deviceName: session.pairing.displayName)

        case .readTeam(let readTeamRequest):
            
            guard let teamIdentity = try IdentityManager.getTeamIdentity() else {
                throw Errors.noTeamIdentity
            }
            
            guard allowed else {
                responseType = .readTeam(.error("\(UserRejectedError())"))
                break
            }
            
            do {
                let expiration = Date().timeIntervalSince1970 + TimeSeconds.hour.multiplied(by: 6)
                let timeReadToken:SigChain.ReadToken = .time(SigChain.TimeToken(readerPublicKey: readTeamRequest.publicKey,
                                                                                expiration: SigChain.UTCTime(expiration)))
                
                let signedMessage = try teamIdentity.sign(body: .readToken(timeReadToken))
                responseType = .readTeam(.ok(signedMessage))
                
            } catch {
                responseType = .readTeam(.error("\(error)"))
            }
            
        case .teamOperation(let teamOperationRequest):
            guard try IdentityManager.hasTeam() else {
                throw Errors.noTeamIdentity
            }
            
            guard allowed else {
                responseType = .teamOperation(.error("rejected"))
                break
            }
            
            do {
                // create the new block
                let (service, response) = try TeamService.shared().appendToMainChainSync(for: teamOperationRequest.operation)
                
                // commit team changes
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                
                // return the `ok` response
                responseType = .teamOperation(.ok(response))
            } catch {
                responseType = .teamOperation(.error("\(error)"))
            }
            
        case .decryptLog(let decryptLogRequest):
            guard let teamIdentity:TeamIdentity = try IdentityManager.getTeamIdentity() else {
                throw Errors.noTeamIdentity
            }
            
            // ensure we're allowed to decrypt
            guard allowed else {
                responseType = .decryptLog(.error("rejected"))
                break
            }
            
            guard decryptLogRequest.wrappedKey.recipientPublicKey == teamIdentity.encryptionPublicKey else {
                responseType = .decryptLog(.error("public key mismatch"))
                break
            }
            
            // TODO: check wrappedKey boxed message is from team member or removed team member
            // This is ok since encryptionPublicKeys are only used for log encryption.
            guard case .logEncryptionKey(let logEncryptionKey) = try teamIdentity.open(boxedMessage: decryptLogRequest.wrappedKey)
            else {
                responseType = .decryptLog(.error("invalid ciphertext"))
                break
            }
            
            
            responseType = .decryptLog(.ok(LogDecryptionResponse(logDecryptionKey: logEncryptionKey)))
    
        case .noOp, .unpair:
            throw Silo.Errors.responseNotNeeded
        }
        
        // save the audit log if we have one
        if let auditLog = auditLog {
            
            // local
            LogManager.shared.save(auditLog: auditLog, sessionID: session.id)
            
            // remote only if we have a team identity
            if var teamIdentity:TeamIdentity = try IdentityManager.getTeamIdentity() {
                do {
                    // try to write & save a team audit log
                    try teamIdentity.writeAndSendLog(auditLog: auditLog)
                } catch AuditLogSendingErrors.loggingDisabled {
                    log("logging disabled...skipping audit log.")
                } catch {
                    log("error saving team audit log: \(error)", .error)
                }
            }
        }
        
        // create the response and return it
        let arn = API.endpointARN ?? ""
        
        let response = Response(requestID: request.id,
                                endpoint: arn,
                                body: responseType,
                                trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
        
        let responseData = try response.jsonData()
        requestCache.setObject(responseData as NSData, forKey: CacheKey(session, request), expires: .seconds(Properties.requestTimeTolerance * 2))

        return response
    }
    
    func cachedResponse(for session:Session,with request:Request) -> Response? {
        if  let cachedResponseData = requestCache[CacheKey(session, request)] as Data?,
            let json:Object = try? JSON.parse(data: cachedResponseData),
            let response = try? Response(json: json)
        {
            return response
        }

        return nil
    }

}
