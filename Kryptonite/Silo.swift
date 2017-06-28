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
import PGPFormat

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
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID)?.appendingPathComponent("cache")
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
            
        case .ssh where Policy.needsUserApproval(for: session, and: request.body),
             .git where Policy.needsUserApproval(for: session, and: request.body),
             .blob where Policy.needsUserApproval(for: session, and: request.body):
            
            try handleRequestRequiresApproval(request: request, session: session, communicationMedium: communicationMedium, completionHandler: completionHandler)
            return
            
        case .me, .ssh, .git, .blob:
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
        
        case .blob(let blobSign):
            //TODO: Analytics
            
            if let error = blobSign.error {
                Policy.notifyUser(errorMessage: error, session: session)
            } else {
                Policy.notifyUser(session: session, request: request)
            }

        case .me, .ack, .unpair:
            break
        }        
        
        try TransportControl.shared.send(response, for: session, completionHandler: completionHandler)
    }

    func handleRequestRequiresApproval(request: Request, session: Session, communicationMedium: CommunicationMedium, completionHandler: (() -> ())?) throws {
        pendingRequests?.removeExpiredObjects()
        if pendingRequests?.object(forKey: CacheKey(session, request)) != nil {
            throw RequestPendingError()
        }
        pendingRequests?.setObject("", forKey: CacheKey(session, request), expires: .seconds(Properties.requestTimeTolerance * 2))
        
        Policy.addPendingAuthorization(session: session, request: request)
        Policy.requestUserAuthorization(session: session, request: request)
        
        if request.sendACK {
            let arn = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? ""
            let ack = Response(requestID: request.id, endpoint: arn, body: .ack(AckResponse()), approvedUntil: Policy.approvedUntilUnixSeconds(for: session), trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
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
                throw KeyManagerError.keyDoesNotExist
            }
            
            var sig:String?
            var err:String?
            do {
                
                if signatureAllowed {
                    
                    // if host auth provided, check known hosts
                    // fails in invalid signature -or- hostname not provided
                    if let verifiedHostAuth = signRequest.verifiedHostAuth {
                        try KnownHostManager.shared.checkOrAdd(verifiedHostAuth: verifiedHostAuth)
                    }
                    
                    // only place where signature should occur
                    sig = try kp.keyPair.signAppendingSSHWirePubkeyToPayload(data: signRequest.data, digestType: signRequest.digestType.based(on: request.version))
                    
                    LogManager.shared.save(theLog: SSHSignatureLog(session: session.id, hostAuth: signRequest.verifiedHostAuth, signature: sig ?? "<err>", displayName: signRequest.display), deviceName: session.pairing.name)
                } else {
                    throw UserRejectedError()
                }
                
            }
            catch let error as UserRejectedError {
                LogManager.shared.save(theLog: SSHSignatureLog(session: session.id, hostAuth: signRequest.verifiedHostAuth, signature: "request failed", displayName: "rejected: \(signRequest.display)"), deviceName: session.pairing.name)
                err = "\(error)"
            }
            catch let error as HostMistmatchError {
                LogManager.shared.save(theLog: SSHSignatureLog(session: session.id, hostAuth: signRequest.verifiedHostAuth, signature: "request failed", displayName: "rejected: \(error)"), deviceName: session.pairing.name)
                err = "\(error)"
            }
            catch {
                err = "\(error)"
            }
            
            responseType = .ssh(SignResponse(sig: sig, err: err))

            
        case .git(let gitSignRequest):
            var sig:String?
            var err:String?
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
                        sig = signature
                        
                        let commitHash = try commit.commitHash(asciiArmoredSignature: asciiArmoredSig.toString()).hex
                        LogManager.shared.save(theLog: CommitSignatureLog(session: session.id, signature: signature, commitHash: commitHash, commit: commit), deviceName: session.pairing.name)
                        
                    case .tag(let tag):
                        
                        let signature = try keyManager.keyPair.signGitTag(with: tag, keyID: keyID).packetData.toBase64()
                        sig = signature
                        
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
                err = "\(error)"
            }
            
            responseType = .git(GitSignResponse(sig: sig, err: err))
            
        case .blob(let blobSign):
            var sig:String?
            var err:String?
            do {
                if signatureAllowed {
                    // only place where git signature should occur
                    
                    let keyManager = try KeyManager.sharedInstance()
                    let keyID = try keyManager.getPGPPublicKeyID()
                    let blobData = Data(bytes: [UInt8](blobSign.blob.utf8))
                    
                    var asciiArmoredSig:AsciiArmorMessage                    
                    if blobSign.isDetached {
                        asciiArmoredSig = try keyManager.keyPair.createAsciiArmoredBinaryDocumentSignature(for: blobData, keyID: keyID)
                    } else {
                        asciiArmoredSig = try keyManager.keyPair.createAsciiArmoredAttachedBinaryDocumentSignature(for: blobData, keyID: keyID)
                    }

                    let signature = asciiArmoredSig.packetData.toBase64()
                    sig = signature
                    
                    //TODO Log BlobSignature
                } else {
                    
                    //TODO: Log BlobSignature
                    throw UserRejectedError()
                }
                
            }  catch {
                err = "\(error)"
            }
            
            responseType = .blob(BlobSignResponse(sig: sig, err: err))

        case .me(let meRequest):
            let keyManager = try KeyManager.sharedInstance()
            
            var pgpPublicKey:Data?
            if let pgpUserID = meRequest.pgpUserId {
                pgpPublicKey = try keyManager.loadPGPPublicKey(for: pgpUserID).packetData
            }
            
            responseType = .me(MeResponse(me: MeResponse.Me(email: try keyManager.getMe(), publicKeyWire: try keyManager.keyPair.publicKey.wireFormat(), pgpPublicKey: pgpPublicKey)))

        case .noOp, .unpair:
            throw ResponseNotNeededError()
        }
        
        let arn = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? ""
        
        let response = Response(requestID: request.id, endpoint: arn, body: responseType, approvedUntil: Policy.approvedUntilUnixSeconds(for: session), trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
        
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
