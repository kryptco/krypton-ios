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
            let payload = payload,
            let signature = signature as Data?
        else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return HashChain.Block(payload: payload, signature: signature)
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        if #available(iOS 10.0, *) {
            self.init(context: context)
        } else {
            self.init(entity: NSEntityDescription.entity(forEntityName: "DataBlock", in: context)!, insertInto: context)
        }
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
        if #available(iOS 10.0, *) {
            self.init(context: context)
        } else {
            self.init(entity: NSEntityDescription.entity(forEntityName: "DataSSHHostKey", in: context)!, insertInto: context)
        }
    }

}

extension DataMember {
    func member() throws -> Team.MemberIdentity {
        guard
            let publicKey = publicKey as Data?,
            let email = email,
            let sshPublicKey = sshPublicKey as Data?,
            let pgpPublicKey = pgpPublicKey as Data?
        else {
            throw TeamDataManager.Errors.missingObjectField
        }
        
        return Team.MemberIdentity(publicKey: publicKey,
                                   email: email,
                                   sshPublicKey: sshPublicKey,
                                   pgpPublicKey: pgpPublicKey)
    }
    
    convenience init(helper context: NSManagedObjectContext) {
        if #available(iOS 10.0, *) {
            self.init(context: context)
        } else {
            self.init(entity: NSEntityDescription.entity(forEntityName: "DataMember", in: context)!, insertInto: context)
        }
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
        if #available(iOS 10.0, *) {
            self.init(context: context)
        } else {
            self.init(entity: NSEntityDescription.entity(forEntityName: "DataTeam", in: context)!, insertInto: context)
        }
    }

}


class TeamDataManager {
    
    private var mutex = Mutex()
    private let teamIdentity:String
    
    init(teamID:Data) {
        teamIdentity = teamID.toBase64(true)
    }
    
    enum Errors:Error {
        case noTeam
        case noTeamName
        case invalidEntity
        case missingObjectField
        case noSuchMember
    }
    
    //MARK: Core Data setup
    lazy var applicationDocumentsDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)?.appendingPathComponent("teams")
    }()
    
    lazy var managedObjectModel:NSManagedObjectModel? = {
        guard let modelURL = Bundle.main.url(forResource:"Teams", withExtension: "momd")
            else {
                return nil
        }
        
        return NSManagedObjectModel(contentsOf: modelURL)
    }()
    
    lazy var persistentStoreCoordinator:NSPersistentStoreCoordinator? = {
        guard
            let directoryURL = self.applicationDocumentsDirectory,
            let managedObjectModel = self.managedObjectModel
            else {
                return nil
        }
        
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
        
        return coordinator
    }()
    
    lazy var managedObjectContext:NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        //managedObjectContext.mergePolicy = NSMergePolicy.error
        return managedObjectContext
    }()
    
    
    /**
        `Team` Data Managment
 
     */
    private func fetchCoreDataTeam() throws -> DataTeam {
        let request:NSFetchRequest<DataTeam> = DataTeam.fetchRequest()
        request.fetchLimit = 1
        request.predicate = self.teamEqualsPredicate(for: self.teamIdentity)
        
        var team:DataTeam!
        
        try performAndWait {
            guard let object = try self.managedObjectContext.fetch(request).first
            else {
                throw Errors.noTeam
            }
            
            team = object
        }
        
        return team
    }
    
    func fetchTeam() throws -> Team {
        defer { mutex.unlock() }
        mutex.lock()
        
        var team:Team!
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            team = try dataTeam.team()
        }
        
        return team
    }
    
    func create(team:Team, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = DataTeam(helper: self.managedObjectContext)
            
            dataTeam.id = self.teamIdentity
            dataTeam.json = try team.jsonData() as NSData
            
            let head = DataBlock(helper: self.managedObjectContext)
            head.payload = block.payload
            head.signature = block.signature as NSData
            
            dataTeam.head = head
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
    
    func fetchAll() throws -> [HashChain.Block] {
        defer { mutex.unlock() }
        mutex.lock()
        
        var blocks:[HashChain.Block] = []
        
        try performAndWait {
            let team = try self.fetchCoreDataTeam()
            
            var head:DataBlock? = team.head
            
            while head != nil {
                try blocks.append(head!.block())
                head = head?.previous
            }
        }
        
        return blocks
    }
    
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
            let newHead = DataBlock(helper: self.managedObjectContext)
            newHead.payload = block.payload
            newHead.signature = block.signature as NSData

            let dataTeam = try self.fetchCoreDataTeam()
            
            self.append(newHead: newHead, to: dataTeam)
        }
        
    }
    
    private func append(newHead:DataBlock, to team:DataTeam) {
        let previousBlock = team.head
        previousBlock?.next = newHead

        newHead.previous = previousBlock
        
        team.head = newHead
    }

    
    /**
        Add/remove member
     */
    func add(member:Team.MemberIdentity, block:HashChain.Block) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newMember = DataMember(helper: self.managedObjectContext)
            newMember.email = member.email
            newMember.publicKey = member.publicKey as NSData
            newMember.sshPublicKey = member.sshPublicKey as NSData
            newMember.pgpPublicKey = member.publicKey as NSData
            
            let newHead = DataBlock(helper: self.managedObjectContext)
            newHead.payload = block.payload
            newHead.signature = block.signature as NSData
            
            self.append(newHead: newHead, to: dataTeam)
            
            dataTeam.addToMembers(newMember)
        }
    }
    
    func remove(member:SodiumPublicKey) throws {
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
            
            let newHead = DataBlock(helper: self.managedObjectContext)
            newHead.payload = block.payload
            newHead.signature = block.signature as NSData
                        
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
        request.predicate = self.sshHostKeyEqualsPredicate(host: hostName, publicKey: hostPublicKey)
        
        var sshHostKeys:[SSHHostKey] = []
        
        try performAndWait {
            for result in try self.managedObjectContext.fetch(request) {
                try sshHostKeys.append(result.sshHostKey())
            }
        }
        
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

    func unpin(sshHostKey:SSHHostKey) throws {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        request.predicate = self.sshHostKeyEqualsPredicate(host: sshHostKey.host, publicKey: sshHostKey.publicKey)
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            for result in try self.managedObjectContext.fetch(request) {
                dataTeam.removeFromPinnedHosts(result)
            }
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
