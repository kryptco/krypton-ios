//
//  Silo.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import JSON
import AwesomeCache


struct InvalidRequestTimeError:Error{}
struct RequestPendingError:Error{}
struct ResponseNotNeededError:Error{}
struct SiloCacheCreationError:Error{}

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

    var requestCache: Cache<NSData>?
    //  store requests waiting for user approval
    var pendingRequests: Cache<NSString>?
    
    // singelton
    private static var sharedSiloMutex = Mutex()
    private static var sharedSilo:Silo?
    class var shared:Silo {
        defer { sharedSiloMutex.unlock() }
        sharedSiloMutex.lock()
        
        guard let ss = sharedSilo else {
            sharedSilo = Silo()
            return sharedSilo!
        }
        return ss
    }

    
    init() {
        requestCache = try? Cache<NSData>(name: "silo_cache", directory: sharedDirectory)
        pendingRequests = try? Cache<NSString>(name: "silo_pending_requests", directory: sharedDirectory)
    }
    
    lazy var sharedDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)?.appendingPathComponent("cache")
    }()


    
    //MARK: Handle Logic
    func handle(request:Request, session:Session, communicationMedium: CommunicationMedium, completionHandler: (()->Void)? = nil) throws {
        mutex.lock()
        defer { mutex.unlock() }

        // ensure session is still active
        guard let _ = SessionManager.shared.get(id: session.id) else {
            throw SessionRemovedError()
        }
        
        // ensure request has not expired
        let now = Date().timeIntervalSince1970
        if abs(now - Double(request.unixSeconds)) > Properties.requestTimeTolerance {
            throw InvalidRequestTimeError()
        }
        
        // check if the request has already been received and cached
        requestCache?.removeExpiredObjects()
        if  let cachedResponseData = requestCache?[CacheKey(session, request)] as Data? {
            let json:Object = try JSON.parse(data: cachedResponseData)
            let response = try Response(json: json)
            try TransportControl.shared.send(response, for: session, completionHandler: completionHandler)
            return
        }
        
        // check if the request has already been received, but is still pending
        pendingRequests?.removeExpiredObjects()
        if pendingRequests?.object(forKey: CacheKey(session, request)) != nil {
            throw RequestPendingError()
        }
                
        // decide if request body can be responded to immediately
        // or doesn't need response,
        // or needs user's approval first
        switch request.body {
        case .unpair:
            Analytics.postEvent(category: "device", action: "unpair", label: "request")
            
            SessionManager.shared.remove(session: session)
            TransportControl.shared.remove(session: session, sendUnpairResponse: false)
            
            throw SessionRemovedError()
            
        case .noOp:
            return
            
        case .decryptLog,
             .teamOperation,
             .readTeam,
             .createTeam,
             .ssh where Policy.needsUserApproval(for: session, and: request.body),
             .git where Policy.needsUserApproval(for: session, and: request.body):
            
            // record this request as pending
            pendingRequests?.setObject("", forKey: CacheKey(session, request), expires: .seconds(Properties.requestTimeTolerance * 2))

            try handleRequestRequiresApproval(request: request, session: session, communicationMedium: communicationMedium, completionHandler: completionHandler)
            return
            
        case .me, .ssh, .git:
            break
        }

        // otherwise, continue with creating and sending the response
        let response = try responseFor(request: request, session: session, signatureAllowed: true)
        
        // analytics / notify user on error for signature response
        switch response.body {
        case .ssh(let sign):
            Analytics.postEvent(category: request.body.analyticsCategory, action: "automatic approval", label: communicationMedium.rawValue)
            
            if let error = sign.error {
                Policy.notifyUser(errorMessage: error, session: session)
            } else {
                Policy.notifyUser(session: session, request: request)
            }
            
            if case .ssh(let sshRequest) = request.body, sshRequest.verifiedHostAuth == nil {
                Analytics.postEvent(category: "host", action: "unknown")
            }

        case .git(let gitSign):
            Analytics.postEvent(category: request.body.analyticsCategory, action: "automatic approval", label: communicationMedium.rawValue)
            
            if let error = gitSign.error {
                Policy.notifyUser(errorMessage: error, session: session)
            } else {
                Policy.notifyUser(session: session, request: request)
            }

        case .decryptLog, .teamOperation, .readTeam, .createTeam, .me, .ack, .unpair:
            break
        }
        
        try TransportControl.shared.send(response, for: session, completionHandler: completionHandler)
    }

    func handleRequestRequiresApproval(request: Request, session: Session, communicationMedium: CommunicationMedium, completionHandler: (() -> ())?) throws {
        
        Policy.addPendingAuthorization(session: session, request: request)
        Policy.requestUserAuthorization(session: session, request: request)
        
        if request.sendACK {
            let arn = API.endpointARN ?? ""
            let ack = Response(requestID: request.id, endpoint: arn, body: .ack(.ok(AckResponse())), approvedUntil: Policy.approvedUntilUnixSeconds(for: session), trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
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
        
        pendingRequests?.removeObject(forKey: CacheKey(session, request))
    }
    
    func isPending(request:Request, for session:Session) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        
        pendingRequests?.removeExpiredObjects()
        if pendingRequests?.object(forKey: CacheKey(session, request)) != nil {
            return true
        }
        
        return false
    }

    
    // MARK: Response
    
    func lockResponseFor(request:Request, session:Session, signatureAllowed:Bool) throws -> Response {
        mutex.lock()
        defer { mutex.unlock() }
        return try responseFor(request: request, session: session, signatureAllowed: signatureAllowed)
    }
    
    // precondition: mutex locked
    private func responseFor(request:Request, session:Session, signatureAllowed:Bool) throws -> Response {
        let requestStart = Date().timeIntervalSince1970
        defer { log("response took \(Date().timeIntervalSince1970 - requestStart) seconds") }
        
        // the response type
        var responseType:ResponseBody
        
        // craft a response to the request type
        // given the user's approval: `signatureAllowed`
        switch request.body {
        case .ssh(let signRequest):
            let kp = try KeyManager.sharedInstance()
            
            if try kp.keyPair.publicKey.fingerprint() != signRequest.fingerprint.fromBase64() {
                throw KeyManager.Errors.keyDoesNotExist
            }
            
            var result:ResponseResult<SSHSignResponse>
            do {
                
                if signatureAllowed {
                    
                    // team known hosts
                    // if team exists then check for pinned known hosts
                    if  let verifiedHostAuth = signRequest.verifiedHostAuth,
                        let teamIdentity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity
                    {
                        try teamIdentity.dataManager.check(verifiedHost: verifiedHostAuth)
                    }
                    
                    // local known hosts
                    // if host auth provided, check known hosts
                    // fails in invalid signature -or- hostname not provided
                    if let verifiedHostAuth = signRequest.verifiedHostAuth {
                        try KnownHostManager.shared.checkOrAdd(verifiedHostAuth: verifiedHostAuth)
                    }
                    
                    // only place where signature should occur
                    let signature = try kp.keyPair.signAppendingSSHWirePubkeyToPayload(data: signRequest.data, digestType: signRequest.digestType.based(on: request.version))
                    result = .ok(SSHSignResponse(signature: signature))
                    
                    LogManager.shared.save(theLog: SSHSignatureLog(session: session.id, hostAuth: signRequest.verifiedHostAuth, signature: signature, displayName: signRequest.display), deviceName: session.pairing.name)
                } else {
                    throw UserRejectedError()
                }
                
            }
            catch let error as UserRejectedError {
                LogManager.shared.save(theLog: SSHSignatureLog(session: session.id, hostAuth: signRequest.verifiedHostAuth, signature: "request failed", displayName: "rejected: \(signRequest.display)"), deviceName: session.pairing.name)
                result = .error("\(error)")
            }
            catch let error as HostMistmatchError {
                LogManager.shared.save(theLog: SSHSignatureLog(session: session.id, hostAuth: signRequest.verifiedHostAuth, signature: "request failed", displayName: "rejected: \(error)"), deviceName: session.pairing.name)
                result = .error("\(error)")
            }
            catch {
                result = .error("\(error)")
            }
            
            responseType = .ssh(result)

            
        case .git(let gitSignRequest):
            var result:ResponseResult<GitSignResponse>
            
            do {
                if signatureAllowed {
                    // only place where git signature should occur
                    let keyManager = try KeyManager.sharedInstance()
                    
                    let keyID = try keyManager.getPGPPublicKeyID()                    
                    let _ = keyManager.updatePGPUserIDPreferences(for: gitSignRequest.userId)

                    switch gitSignRequest.git {
                    case .commit(let commit):
                        
                        let asciiArmoredSig = try keyManager.keyPair.signGitCommit(with: commit, keyID: keyID)
                        let signature = asciiArmoredSig.packetData.toBase64()
                        result = .ok(GitSignResponse(signature: signature))

                        let commitHash = try commit.commitHash(asciiArmoredSignature: asciiArmoredSig.toString()).hex
                        LogManager.shared.save(theLog: CommitSignatureLog(session: session.id, signature: signature, commitHash: commitHash, commit: commit), deviceName: session.pairing.name)
                        
                    case .tag(let tag):
                        
                        let signature = try keyManager.keyPair.signGitTag(with: tag, keyID: keyID).packetData.toBase64()
                        result = .ok(GitSignResponse(signature: signature))

                        LogManager.shared.save(theLog: TagSignatureLog(session: session.id, signature: signature, tag: tag), deviceName: session.pairing.name)
                    }
                    
                } else {
                    
                    switch gitSignRequest.git {
                    case .commit(let commit):
                        LogManager.shared.save(theLog: CommitSignatureLog(session: session.id, signature: CommitSignatureLog.rejectedConstant, commitHash: "", commit: commit), deviceName: session.pairing.name)
                    case .tag(let tag):
                        LogManager.shared.save(theLog: TagSignatureLog(session: session.id, signature: TagSignatureLog.rejectedConstant, tag: tag), deviceName: session.pairing.name)
                    }
                    
                    throw UserRejectedError()
                }
                
            }  catch {
                result = .error("\(error)")
            }
            
            responseType = .git(result)
            
        case .me(let meRequest):
            let keyManager = try KeyManager.sharedInstance()
            
            var pgpPublicKey:Data?
            if let pgpUserID = meRequest.pgpUserId {
                pgpPublicKey = try keyManager.loadPGPPublicKey(for: pgpUserID).packetData
            }
            
            let me = MeResponse(me: MeResponse.Me(email: try IdentityManager.getMe(),
                                                  publicKeyWire: try keyManager.keyPair.publicKey.wireFormat(),
                                                  pgpPublicKey: pgpPublicKey))
            responseType = .me(.ok(me))

        case .decryptLog, .readTeam, .teamOperation, .createTeam, .noOp, .unpair:
            throw ResponseNotNeededError()
        }
        
        let arn = API.endpointARN ?? ""
        
        let response = Response(requestID: request.id,
                                endpoint: arn,
                                body: responseType,
                                approvedUntil: Policy.approvedUntilUnixSeconds(for: session),
                                trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
        
        let responseData = try response.jsonData() as NSData
        
        requestCache?.setObject(responseData, forKey: CacheKey(session, request), expires: .seconds(Properties.requestTimeTolerance * 2))
        
        return response

    }
    
    func cachedResponse(for session:Session,with request:Request) -> Response? {
        if  let cachedResponseData = requestCache?[CacheKey(session, request)] as Data?,
            let json:Object = try? JSON.parse(data: cachedResponseData),
            let response = try? Response(json: json)
        {
            return response
        }

        return nil
    }

}
