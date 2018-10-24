//
//  TeamDataTypes.swift
//  Krypton
//
//  Created by Alex Grinman on 12/9/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import CoreData

//MARK: Core Data Types

extension DataSignedMessage {
    func toSignedMessage() throws -> SigChain.SignedMessage {
        guard
            let publicKey = publicKey as Data?,
            let message = message,
            let signature = signature as Data?
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        return SigChain.SignedMessage(publicKey: publicKey, message: message, signature: signature)
    }
    
    convenience init(signedMessage:SigChain.SignedMessage, helper context:NSManagedObjectContext) {
        self.init(helper: context)
        self.publicKey = signedMessage.publicKey
        self.message = signedMessage.message
        self.signature = signedMessage.signature
        self.blockHash = signedMessage.hash()
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataSignedMessage", in: context)!, insertInto: context)
    }
    
}


extension DataLogBlock {
    func toSignedMessage() throws -> SigChain.SignedMessage {
        guard
            let publicKey = publicKey as Data?,
            let message = message,
            let signature = signature as Data?
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        return SigChain.SignedMessage(publicKey: publicKey, message: message, signature: signature)
    }
    
    convenience init(signedMessage:SigChain.SignedMessage, helper context:NSManagedObjectContext) {
        self.init(helper: context)
        self.publicKey = signedMessage.publicKey
        self.message = signedMessage.message
        self.signature = signedMessage.signature
        self.blockHash = signedMessage.hash()
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataLogBlock", in: context)!, insertInto: context)
    }
}

struct UnsentAuditLog {
    let data:Data
    let date:Date
    let dataHash:Data
}

extension DataUnsentAuditLog {
    func toUnsentAuditLog() throws -> UnsentAuditLog {
        guard   let data = data as Data?,
                let hash = dataHash as Data?,
                let date = date as Date?
        else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return UnsentAuditLog(data: data, date: date, dataHash: hash)
    }
    
    convenience init(unsentAuditLog:UnsentAuditLog, helper context:NSManagedObjectContext) {
        self.init(helper: context)
        self.data = unsentAuditLog.data
        self.date = unsentAuditLog.date
        self.dataHash = unsentAuditLog.dataHash
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataUnsentAuditLog", in: context)!, insertInto: context)
    }
    
    static func batchDeleteRequest() -> NSBatchDeleteRequest {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "DataUnsentAuditLog")
        return NSBatchDeleteRequest(fetchRequest: fetch)
    }
}

extension DataSSHHostKey {
    func sshHostKey() throws -> SSHHostKey {
        guard
            let host = host,
            let publicKey = publicKey as Data?
            
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        return SSHHostKey(host: host, publicKey: publicKey)
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataSSHHostKey", in: context)!, insertInto: context)
    }
}

extension DataRemovedMember {
    convenience init(helper context: NSManagedObjectContext, identity:SigChain.Identity) {
        self.init(helper: context)
        self.email = identity.email
        self.publicKey = identity.publicKey.data
        self.encryptionPublicKey = identity.encryptionPublicKey.data
        self.sshPublicKey = identity.sshPublicKey
        self.pgpPublicKey = identity.pgpPublicKey
    }
    
    func member() throws -> SigChain.Identity {
        guard
            let publicKey = publicKey as Data?,
            let encryptionPublicKey = encryptionPublicKey as Data?,
            let email = email,
            let sshPublicKey = sshPublicKey as Data?,
            let pgpPublicKey = pgpPublicKey as Data?
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        return SigChain.Identity(publicKey: publicKey.bytes,
                                 encryptionPublicKey: encryptionPublicKey.bytes,
                                 email: email,
                                 sshPublicKey: sshPublicKey,
                                 pgpPublicKey: pgpPublicKey)
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataRemovedMember", in: context)!, insertInto: context)
    }
    
}


extension DataMember {
    convenience init(helper context: NSManagedObjectContext, member:SigChain.Identity) {
        self.init(helper: context)
        self.email = member.email
        self.publicKey = member.publicKey.data
        self.encryptionPublicKey = member.encryptionPublicKey.data
        self.sshPublicKey = member.sshPublicKey
        self.pgpPublicKey = member.pgpPublicKey
    }
    
    func member() throws -> SigChain.Identity {
        guard
            let publicKey = publicKey as Data?,
            let encryptionPublicKey = encryptionPublicKey as Data?,
            let email = email,
            let sshPublicKey = sshPublicKey as Data?,
            let pgpPublicKey = pgpPublicKey as Data?
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        return SigChain.Identity(publicKey: publicKey.bytes,
                                 encryptionPublicKey: encryptionPublicKey.bytes,
                                 email: email,
                                 sshPublicKey: sshPublicKey,
                                 pgpPublicKey: pgpPublicKey)
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataMember", in: context)!, insertInto: context)
    }
    
}

extension DataTeam {
    func team() throws -> Team {
        guard let json = self.json as Data? else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return try Team(jsonData: json)
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataTeam", in: context)!, insertInto: context)
    }
}

extension DataDomainMemberInvitation {
    convenience init(helper context: NSManagedObjectContext, invite:SigChain.IndirectInvitation, domain:String) {
        self.init(helper: context)
        self.noncePublicKey = invite.noncePublicKey.data
        self.inviteCiphertext = invite.inviteCiphertext
        self.inviteSymmetricKeyHash = invite.inviteSymmetricKeyHash
        self.domain = domain
    }
    
    func invite() throws -> SigChain.IndirectInvitation {
        guard
            let noncePublicKey = noncePublicKey as Data?,
            let inviteCiphertext = inviteCiphertext as Data?,
            let inviteSymmetricKeyHash = inviteSymmetricKeyHash as Data?,
            let domain = domain as String?
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        return SigChain.IndirectInvitation(noncePublicKey: noncePublicKey.bytes,
                                         inviteSymmetricKeyHash: inviteSymmetricKeyHash,
                                         inviteCiphertext: inviteCiphertext,
                                         restriction: .domain(domain))
        
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataDomainMemberInvitation", in: context)!, insertInto: context)
    }
    
    static func batchDeleteRequest() -> NSBatchDeleteRequest {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "DataDomainMemberInvitation")
        return NSBatchDeleteRequest(fetchRequest: fetch)
    }
    
}

extension DataIndividualMemberInvitation {
    convenience init(helper context: NSManagedObjectContext, invite:SigChain.IndirectInvitation, emails:[String]) {
        self.init(helper: context)
        self.noncePublicKey = invite.noncePublicKey.data
        self.inviteCiphertext = invite.inviteCiphertext
        self.inviteSymmetricKeyHash = invite.inviteSymmetricKeyHash
        self.emails = emails.joined(separator: ",")
    }
    
    func invite() throws -> SigChain.IndirectInvitation {
        guard
            let noncePublicKey = noncePublicKey as Data?,
            let inviteCiphertext = inviteCiphertext as Data?,
            let inviteSymmetricKeyHash = inviteSymmetricKeyHash as Data?,
            let emailList = emails as String?
            else {
                throw TeamDataManager.Errors.missingObjectField
        }
        
        let parsedEmails = emailList.components(separatedBy: ",")
        
        return SigChain.IndirectInvitation(noncePublicKey: noncePublicKey.bytes,
                                         inviteSymmetricKeyHash: inviteSymmetricKeyHash,
                                         inviteCiphertext: inviteCiphertext,
                                         restriction: .emails(parsedEmails))
        
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataIndividualMemberInvitation", in: context)!, insertInto: context)
    }
    
    static func batchDeleteRequest() -> NSBatchDeleteRequest {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "DataIndividualMemberInvitation")
        return NSBatchDeleteRequest(fetchRequest: fetch)
    }
}

extension DataDirectMemberInvitation {
    convenience init(helper context: NSManagedObjectContext, invite:SigChain.DirectInvitation) {
        self.init(helper: context)
        self.publicKey = invite.publicKey.data
        self.email = invite.email
    }
    
    func invite() throws -> SigChain.DirectInvitation {
        guard
            let publicKey = publicKey as Data?,
            let email = email as String?
        else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return SigChain.DirectInvitation(publicKey: publicKey.bytes, email: email)
        
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataDirectMemberInvitation", in: context)!, insertInto: context)
    }
    
    static func batchDeleteRequest() -> NSBatchDeleteRequest {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "DataDirectMemberInvitation")
        return NSBatchDeleteRequest(fetchRequest: fetch)
    }
}

extension DataPublicKeyWrappedLogEncryptionTo {
    convenience init(helper context: NSManagedObjectContext, publicKey:SodiumBoxPublicKey) {
        self.init(helper: context)
        self.publicKey = publicKey.data
    }
    
    func toPublicKey() throws -> SodiumBoxPublicKey {
        guard let publicKey = self.publicKey as Data? else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return publicKey.bytes
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataPublicKeyWrappedLogEncryptionTo", in: context)!, insertInto: context)
    }
    
}




