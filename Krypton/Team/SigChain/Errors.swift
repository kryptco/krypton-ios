//
//  SigChain+Errors.swift
//  Krypton
//
//  Created by Alex Grinman on 11/28/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension SigChain {
    
    enum Errors:Error {
        case duplicateEmailAddress
        
        case unknownMessageBodyType
        
        case badSignature
        case badMainChainType
        case badLogChainType
        
        case badOperation
        case badBlockHash
        case badLoggingEndpoint
        case badTeamPointer
        case badInvitationType
        case badIndirectInvitationRestriction
        
        case invitePublicKeyAlreadyExists
        
        case directInviteForExistingMemberEmail
        case directInviteForExistingMemberPublicKey
        case indirectInviteForExistingMemberEmail
        
        case loggingEndpointAlreadyExists
        case loggingEndpointDoesNotExist
        
        case hostKeyAlreadyPinned
        case hostKeyNotPinned
        
        case memberIsAlreadyAdmin
        case memberNotAdmin

        case badLogPointer
        case badLogsFilter
        case badLogOperation
        
        case badPlaintextBody

        case inviteEncryptionFailed
        
        case missingCreateChain
        case unexpectedBlock
        
        case memberDoesNotExist
        
        case payloadSignatureFailed
        
        case unknownAcceptBlockPublicKey

        case signerNotAdmin
        case signerCannotRemoveSelf
        case teamPublicKeyMismatch
        
        case rotateKeyGeneration
        
        case unknownLoggingEndpoint
        case missingLastLogBlockHash
        case logEncryptionFailed
        
        case badPushSubscriptionType
        case badPushDeviceType
        
        case noLogLastBlockHash
        
        case majorVersionIncompatible
        
        case badReadLogsRequest
        case notLogChainBlock
        case signerNotLogChainAuthor
        case expectedLogChainGenesis
        case expectedLogChainAppend
        case mismatchedTeamPointerPublicKey
        case missingTeamPointerBlockHash
        case missingLogChainWrappedKey
        case badLogChainWrappedKey
        case badLogBlockHash

    }
}

