//
//  TeamDataManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import CoreData
import JSON

//MARK: Core Data Types
extension DataBlock {
    func block() throws -> HashChain.Block {
        guard
            let publicKey = publicKey as Data?,
            let payload = payload,
            let signature = signature as Data?
        else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return HashChain.Block(publicKey: publicKey, payload: payload, signature: signature)
    }
    
    convenience init(block:HashChain.Block, helper context:NSManagedObjectContext) {
        self.init(helper: context)
        self.publicKey = block.publicKey as NSData
        self.payload = block.payload
        self.signature = block.signature as NSData
        self.blockHash = block.hash() as NSData
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        //workaround: https://stackoverflow.com/questions/6946798/core-data-store-cannot-hold-instances-of-entity-cocoa-error-134020
        self.init(entity: NSEntityDescription.entity(forEntityName: "DataBlock", in: context)!, insertInto: context)
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

extension DataMember {
    convenience init(helper context: NSManagedObjectContext, member:Team.MemberIdentity) {
        self.init(helper: context)
        self.email = member.email
        self.publicKey = member.publicKey as NSData
        self.encryptionPublicKey = member.encryptionPublicKey as NSData
        self.sshPublicKey = member.sshPublicKey as NSData
        self.pgpPublicKey = member.publicKey as NSData
    }
    
    func member() throws -> Team.MemberIdentity {
        guard
            let publicKey = publicKey as Data?,
            let encryptionPublicKey = encryptionPublicKey as Data?,
            let email = email,
            let sshPublicKey = sshPublicKey as Data?,
            let pgpPublicKey = pgpPublicKey as Data?
        else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return Team.MemberIdentity(publicKey: publicKey,
                                   encryptionPublicKey: encryptionPublicKey,
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


class TeamDataManager {
    
    private var mutex = Mutex()
    private let teamIdentity:String
    
    private var managedObjectModel:NSManagedObjectModel?
    private var persistentStoreCoordinator:NSPersistentStoreCoordinator?
    private var managedObjectContext:NSManagedObjectContext

    init(teamID:Data) {
        teamIdentity = teamID.toBase64(true)
        
        // managed object model
        if let modelURL = Bundle.main.url(forResource:"Teams", withExtension: "momd") {
            managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        }
        
        // persistant store coordinator
        if
            let directoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)?.appendingPathComponent("teams"),
            let managedObjectModel = self.managedObjectModel
        {
            // db file
            let url = directoryURL.appendingPathComponent("db_\(self.teamIdentity).sqlite")
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            
            do {
                // create file if it doesn't exist
                if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                }
                
                let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                               NSInferMappingModelAutomaticallyOption: true]
                
                let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
                store.didAdd(to: coordinator)
            } catch let e {
                log("Persistance store error: \(e)", .error)
            }
            
            persistentStoreCoordinator = coordinator
        }
        
        // managed object context
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        return
    }
    
    enum Errors:Error {
        case noTeam
        case noTeamName
        case invalidEntity
        case missingObjectField
        case noSuchMember
        case prospectiveAdminIsNotMember
    }
    
    
    /**
        `Team` Data Managment
 
     */
    private func fetchCoreDataTeam() throws -> DataTeam {
        let request:NSFetchRequest<DataTeam> = DataTeam.fetchRequest()
        request.fetchLimit = 1
        request.predicate = self.teamEqualsPredicate(for: self.teamIdentity)
        
        guard let team = try self.managedObjectContext.fetch(request).first
            else {
                throw Errors.noTeam
        }
        
        return team
    }
    
    func fetchTeam() throws -> Team {
        defer { mutex.unlock() }
        mutex.lock()
        
        var team:Team!
        
        try performAndWait {
            team = try self.fetchCoreDataTeam().team()
        }
        
        return team
    }
    
    func create(team:Team, creator:Team.MemberIdentity, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = DataTeam(helper: self.managedObjectContext)
            dataTeam.id = self.teamIdentity
            dataTeam.json = try team.jsonData() as NSData

            let admin = DataMember(helper: self.managedObjectContext, member: creator)
            admin.isAdmin = true
            dataTeam.addToMembers(admin)

            let head = DataBlock(block: block, helper: self.managedObjectContext)
            dataTeam.head = head
            dataTeam.lastBlockHash = block.hash() as NSData
            dataTeam.addToBlocks(head)
        }
    }
    
    func set(team:Team) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            dataTeam.json = try team.jsonData() as NSData
        }
    }
    
    /**
        Fetch helpers
     */
    
    ///MARK: Blocks
    
    func fetchAll() throws -> [HashChain.Block] {
        defer { mutex.unlock() }
        mutex.lock()

        var blocks:[HashChain.Block] = []
        
        try performAndWait {
            var pointer = try self.fetchCoreDataTeam().head
            while pointer != nil {
                try blocks.append(pointer!.block())
                pointer = pointer?.previous
            }
        }
        
        return blocks
    }
    
    func hasBlock(for hash:Data) throws -> Bool {
        return try self.fetchBlock(for: hash) != nil
    }
    
    func fetchBlocks(after hash:Data) throws -> [HashChain.Block] {
        let block = try self.fetchBlock(for: hash)
        
        defer { mutex.unlock() }
        mutex.lock()
        
        var blocks:[HashChain.Block] = []
        
        try performAndWait {
            var pointer = block?.next
            while pointer != nil {
                try blocks.append(pointer!.block())
                pointer = pointer?.previous
            }
        }
        
        return blocks
    }
    
    private func fetchBlock(for hash:Data) throws -> DataBlock? {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataBlock> = DataBlock.fetchRequest()
        
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataBlock.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let blockHashPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataBlock.blockHash)),
            rightExpression: NSExpression(forConstantValue: hash),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, blockHashPredicate])
        
        var block:DataBlock?
        
        try performAndWait {
            let blocks = try self.managedObjectContext.fetch(request)
            block = blocks.first
        }
        
        return block
    }
    
    func lastBlockHash() throws -> Data? {
        defer { mutex.unlock() }
        mutex.lock()
        
        var blockHash:Data?
        try performAndWait {
            
            var team:DataTeam?
            do {
                team = try self.fetchCoreDataTeam()
            } catch Errors.noTeam {
                blockHash = nil
                return
            } catch {
                throw error
            }
            
            if let hash = team?.lastBlockHash as Data? {
                blockHash = Data(hash)
            }
        }
        
        return blockHash
    }
    
    
    ///MARK: Members
    
    func fetchAll() throws -> [Team.MemberIdentity] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        request.predicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        
        var members:[Team.MemberIdentity] = []
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                try members.append($0.member())
            }
        }
        
        return members
    }
    
    func fetchAdmins() throws -> [Team.MemberIdentity] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        
        let isAdminPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.isAdmin)),
            rightExpression: NSExpression(forConstantValue: true),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, isAdminPredicate])
        
        var admins:[Team.MemberIdentity] = []
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                try admins.append($0.member())
            }
        }
        
        return admins
    }

    
    private func fetchMember(for publicKey:SodiumPublicKey) throws -> DataMember? {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, memberPredicate])
        
        var member:DataMember?
        
        try performAndWait {
            member = try self.managedObjectContext.fetch(request).first
        }
        
        return member
    }


    /// MARK: Host Keys
    func fetchAll() throws -> [SSHHostKey] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        request.predicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        var pinnedHosts = [SSHHostKey]()
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                try pinnedHosts.append($0.sshHostKey())
            }
        }
        
        return pinnedHosts
    }
    
    /**
        Add a new block
     */
    func append(block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)
            let dataTeam = try self.fetchCoreDataTeam()
            
            self.append(newHead: newHead, to: dataTeam)
        }
        
    }
    
    private func append(newHead:DataBlock, to team:DataTeam) {
        team.addToBlocks(newHead)

        let currentHead = team.head
        currentHead?.next = newHead
        team.head = newHead
        team.lastBlockHash = newHead.blockHash
    }
    
    /**
        Add/remove member
     */
    func add(member:Team.MemberIdentity, isAdmin:Bool = false, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newMember = DataMember(helper: self.managedObjectContext, member: member)
            newMember.isAdmin = isAdmin
            
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)

            self.append(newHead: newHead, to: dataTeam)
            
            dataTeam.addToMembers(newMember)
        }
    }
    
    func remove(member:SodiumPublicKey, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: member as NSData),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, memberPredicate])
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            for member in try self.managedObjectContext.fetch(request) {
                dataTeam.removeFromMembers(member)
            }
            
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)
            
            self.append(newHead: newHead, to: dataTeam)
        }

    }
    
    /**
        Add/remove admins
        Get admin public keys
     */
    func add(admin publicKey:SodiumPublicKey, block:HashChain.Block) throws {
        
        // first fetch the team member
        guard let adminMember = try self.fetchMember(for: publicKey) else {
            throw Errors.prospectiveAdminIsNotMember
        }
        
        // continue adding the admin
        defer { mutex.unlock() }
        mutex.lock()
    
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            // make the member an admin
            adminMember.isAdmin = true
            
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }
    }
    
    func isAdmin(for publicKey:SodiumPublicKey) throws -> Bool {
        let admins = try self.fetchAdmins()
        return admins.filter { $0.publicKey == publicKey }.isEmpty == false
    }
    
    func remove(admin publicKey:SodiumPublicKey, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey as NSData),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, memberPredicate])
        
        try performAndWait {
            for adminToRemove in try self.managedObjectContext.fetch(request) {
                adminToRemove.isAdmin = false
            }
            
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }
        
    }
    
    /**
        Pin/Unpin/check Known Hosts
     */
    func pin(sshHostKey:SSHHostKey, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newHost = DataSSHHostKey(helper: self.managedObjectContext)
            newHost.host = sshHostKey.host
            newHost.publicKey = sshHostKey.publicKey as NSData
            
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)
            
            self.append(newHead: newHead, to: dataTeam)
            
            dataTeam.addToPinnedHosts(newHost)
        }
    }
    
    /** Match verifiedHostAuth (hostName, publicKey) to a pin (host, publickey)
        - returns true if host name is pinned and public key matches
        - returns false if host name is not pinned
        - throws HostMistmatchError if host name is pinned but public key is mismatched
    */
    func check(verifiedHost:VerifiedHostAuth) throws {
        guard let hostName = verifiedHost.hostName
        else {
            throw HostAuthHasNoHostnames()
        }
        
        let hostPublicKey = try verifiedHost.hostKey.fromBase64()
        
        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let hostPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.host)),
            rightExpression: NSExpression(forConstantValue: hostName),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        // look for matching hosts the with hostname `hostName`
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, hostPredicate])
        
        var sshHostKeys:[SSHHostKey] = []
        
        try performAndWait {
            for result in try self.managedObjectContext.fetch(request) {
                try sshHostKeys.append(result.sshHostKey())
            }
        }
        
        // if unknown, then it's not pinned
        guard !sshHostKeys.isEmpty else {
            return
        }
        
        let matchingHosts = sshHostKeys.filter { $0.publicKey == hostPublicKey}
        
        guard false == matchingHosts.isEmpty
        else {
            let pinnedPublicKeysJoined = sshHostKeys.map({ $0.publicKey.toBase64() }).joined(separator: ",")
            throw HostMistmatchError(hostName: hostName, expectedPublicKey: pinnedPublicKeysJoined)
        }
    }
    
    /**
     Check if we have a public key verifiedHostAuth's hostName
     - if known host and does match: return true
     - if not known host or public key does not match: return false
     */
    func sshHostKeyExists(for hostName:String) throws -> Bool {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()

        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let hostPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.host)),
            rightExpression: NSExpression(forConstantValue: hostName),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, hostPredicate])

        var sshHostKeys:[SSHHostKey] = []
        
        try performAndWait {
            for result in try self.managedObjectContext.fetch(request) {
                try sshHostKeys.append(result.sshHostKey())
            }
        }

        return !sshHostKeys.isEmpty
    }

    func unpin(sshHostKey:SSHHostKey, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        request.predicate = self.sshHostKeyEqualsPredicate(host: sshHostKey.host, publicKey: sshHostKey.publicKey)
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            for result in try self.managedObjectContext.fetch(request) {
                dataTeam.removeFromPinnedHosts(result)
            }
            
            let newHead = DataBlock(block: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }

    }
    
    // MARK: Predicates
    private func sshHostKeyEqualsPredicate(host:String, publicKey:SodiumPublicKey) -> NSPredicate {
        let teamPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.team.id)),
            rightExpression: NSExpression(forConstantValue: self.teamIdentity),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let hostPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.host)),
            rightExpression: NSExpression(forConstantValue: host),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let publicKeyPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey as NSData),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [teamPredicate, hostPredicate, publicKeyPredicate])

    }
    private func teamEqualsPredicate(for id:String) -> NSPredicate {
        return NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "id"),
            rightExpression: NSExpression(forConstantValue: id),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }
    
    //MARK: Internals
    private func performAndWait(fn:@escaping (() throws -> Void)) throws {
        
        var caughtError:Error?
        self.managedObjectContext.performAndWait {
            do {
                try fn()
            } catch {
                caughtError = error
            }
        }
        
        if let error = caughtError {
            throw error
        }
    }
    
    //MARK: - Core Data Saving/Roll back support
    func saveContext() throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        var caughtError:Error?
        self.managedObjectContext.performAndWait {
            if self.managedObjectContext.hasChanges {
                do {
                    try self.managedObjectContext.save()
                } catch {
                    caughtError = error
                }
            }
        }
        
        if let error = caughtError {
            throw error
        }
    }
    
    func rollbackContext () {
        defer { mutex.unlock() }
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            if self.managedObjectContext.hasChanges {
                self.managedObjectContext.rollback()
            }
        }
    }
}
