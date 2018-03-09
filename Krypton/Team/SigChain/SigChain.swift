//
//  SigChain.swift
//  Krypton
//
//  Created by Alex Grinman on 7/29/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

/**
    Implements the SigChain type system
 */
class SigChain {
    
    typealias EmailAddress = String
    typealias EmailDomain = String
    typealias UTCTime = Int64

    
    static let protocolVersion = Version(major: 1, minor: 0, patch: 0)
    
    // MARK: Unit Type
    /// a signed 'unit type'
    struct SignedMessage {
        typealias SerializedMessage = String
        
        let publicKey:Data
        let message:SerializedMessage
        let signature:Data
        
        func hash() -> Data {
            var dataToHash = Data()

            dataToHash.append(publicKey.SHA256)
            dataToHash.append(Data(bytes: [UInt8](message.utf8)).SHA256)

            return dataToHash.SHA256
        }
    }
    
    /// 'unit type'
    struct Message {
        let header:Header
        let body:Body
    }
    
    
    struct Header {
        let utcTime:UTCTime
        let protocolVersion:Version
    }
    
    enum Body {
        case main(MainChain)
        case log(LogChain)
        case readToken(ReadToken)
        case emailChallenge(EmailChallenge)
        case pushSubscription(PushSubscription)
        case readBillingInfo(ReadBillingInfo)
    }
    
    //MARK: Main Chain
    
    enum MainChain {
        case read(ReadBlocksRequest)
        case create(GenesisBlock)
        case append(Block)
    }
    
    // read
    struct ReadBlocksRequest {
        let teamPointer:TeamPointer
        let nonce:Data
        let token:SignedMessage?
    }
    
    enum TeamPointer {
        case publicKey(SodiumSignPublicKey)
        case lastBlockHash(Data)
    }
    
    enum ReadToken {
        case time(TimeToken)
    }
    
    struct TimeToken {
        let readerPublicKey:SodiumSignPublicKey
        let expiration:UTCTime
    }
    
    struct ReadBlocksResponse {
        let blocks:[SignedMessage]
        let hasMore:Bool
        
        var hasBlocks:Bool {
            return blocks.isEmpty == false
        }
    }
    
    // create
    struct GenesisBlock {
        let creator:Identity
        let teamInfo:TeamInfo
    }
    
    // append
    
    struct Block {
        let lastBlockHash:Data
        let operation:Operation
    }
    
    enum Invitation {
        case direct(DirectInvitation)
        case indirect(IndirectInvitation)
        
        // every invitation must have a public key
        var publicKey:SodiumSignPublicKey {
            switch self {
            case .direct(let direct):
                return direct.publicKey
            case .indirect(let indirect):
                return indirect.noncePublicKey
            }
        }
    }
    
    struct DirectInvitation {
        let publicKey:SodiumSignPublicKey
        let email:EmailAddress
    }
    struct IndirectInvitation {
        enum Restriction {
            case domain(EmailDomain)
            case emails([EmailAddress])
        }
        
        struct Secret {
            let initialTeamPublicKey:SodiumSignPublicKey
            let lastBlockHash:Data
            let nonceKeypairSeed:Data
            let restriction:Restriction
        }

        let noncePublicKey:SodiumSignPublicKey
        let inviteSymmetricKeyHash:Data
        let inviteCiphertext:Data // ciphertext of encrypted `Invite`
        let restriction:Restriction
    }
    
    struct TeamInfo {
        let name:String
    }
    
    
    struct Policy {
        let temporaryApprovalSeconds:UTCTime?
    }
    
    struct Identity {
        let publicKey:SodiumSignPublicKey
        let encryptionPublicKey:SodiumSignPublicKey
        let email:String
        let sshPublicKey:Data
        let pgpPublicKey:Data        
    }
    
    enum LoggingEndpoint {
        case commandEncrypted
    }

    enum Operation {
        typealias IdentityPublicKey = SodiumSignPublicKey
        
        case invite(Invitation)
        case acceptInvite(Identity)
        case closeInvitations
        case leave

        case promote(IdentityPublicKey)
        case demote(IdentityPublicKey)
        case remove(IdentityPublicKey)
        
        case setPolicy(Policy)
        case setTeamInfo(TeamInfo)
        case pinHostKey(SSHHostKey)
        case unpinHostKey(SSHHostKey)
        case addLoggingEndpoint(LoggingEndpoint)
        case removeLoggingEndpoint(LoggingEndpoint)
    }
    
    //MARK: Log Chain
    
    enum LogChain {
        case create(GenesisLogBlock)
        case append(LogBlock)
        case read(ReadLogBlocksRequest)
    }

    // create
    struct GenesisLogBlock {
        let teamPointer:TeamPointer
        let wrappedKeys:[WrappedKey]
    }

    // append
    struct LogBlock {
        let lastBlockHash:Data
        let operation:LogOperation
    }
    
    struct WrappedKey {
        let recipientPublicKey:SodiumBoxPublicKey
        let ciphertext:Data
    }
    
    enum LogOperation {
        case addWrappedKeys([WrappedKey])
        case rotateKey([WrappedKey])
        case encryptLog(EncryptedLog)
    }
    
    struct EncryptedLog {
        let ciphertext:Data
    }
    
    // read
    
    struct ReadLogBlocksRequest {
        let nonce: Data
        let filter: LogsFilter
    }
    
    struct ReadLogBlocksResponse {
        let logBlocks: [SignedMessage]
        let more: Bool
    }
    
    enum LogsFilter {
        case member(LogChainPointer)
    }
    
    enum LogChainPointer {
        case genesisBlock(LogChainGenesisPointer)
        case lastBlockHash(Data)
    }
    
    struct LogChainGenesisPointer {
        let teamPublicKey: Data
        let memberPublicKey: Data
    }
    
    //MARK: Boxed Messages
    
    struct BoxedMessage {
        let recipientPublicKey:SodiumBoxPublicKey
        let senderPublicKey:SodiumBoxPublicKey
        let ciphertext:Data
        
        func toWrappedKey() -> WrappedKey {
            return WrappedKey(recipientPublicKey: recipientPublicKey, ciphertext: ciphertext)
        }
    }
    
    enum PlaintextBody {
        case logEncryptionKey(SodiumSecretBoxKey)
    }

    //MARK: Email Challenge
    
    struct EmailChallenge {
        let nonce:Data
    }
    
    //MARK: Push Subscription
    struct PushSubscription {
        let teamPointer:TeamPointer
        let action:PushSubscriptionAction
    }
    
    enum PushSubscriptionAction {
        case subscribe(PushDevice)
        case unsubscribe
    }
    
    enum PushDevice {
        typealias Token = String
        typealias ARN = String
        
        case iOS(Token)
        case android(Token)
        case queue(ARN)        
    }
    
    // MARK: Read Billing
    
    struct ReadBillingInfo {
        let teamPublicKey:SodiumSignPublicKey
        let token:SignedMessage?
    }
}
