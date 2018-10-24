//
//  TeamDataManager.swift
//  Krypton
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import CoreData
import JSON

class TeamDataManager {
    
    private var mutex = Mutex()
    private let dbName:String
    
    private var managedObjectModel:NSManagedObjectModel?
    private var persistentStoreCoordinator:NSPersistentStoreCoordinator?
    private var managedObjectContext:NSManagedObjectContext

    init(name:String, readOnly:Bool = false) throws {
        dbName = name
        
        // the secure local directory
        // this db directory is not backed up
        let directoryURL = try SecureLocalStorage.directory(for: "teams_db")
        
        // load the object model
        guard   let modelURL = Bundle.main.url(forResource:"Teams", withExtension: "momd"),
                let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw Errors.createDatabase
        }
        
        // create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var options:[String:Any] = [NSMigratePersistentStoresAutomaticallyOption: true,
                                    NSInferMappingModelAutomaticallyOption: true]
        
        if readOnly {
            options[NSReadOnlyPersistentStoreOption] = true
        }
        
        // db file
        let dbURL = directoryURL.appendingPathComponent("db_\(self.dbName).sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
        store.didAdd(to: coordinator)
        
        persistentStoreCoordinator = coordinator

        // managed object context
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
    }
    
    enum Errors:Error {
        case noTeam
        case noTeamName
        case invalidEntity
        case missingObjectField
        case noSuchMember
        case prospectiveAdminIsNotMember
        case memberAlreadyExists
        
        case createDatabase
        
        case noGenesisBlock
        case noLogGenesisBlock
    }
    
    
    /**
        `Team` Data Managment
 
     */
    private func fetchCoreDataTeam() throws -> DataTeam {
        let request:NSFetchRequest<DataTeam> = DataTeam.fetchRequest()
        request.fetchLimit = 1

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
    
    func create(team:Team, creator:SigChain.Identity, block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = DataTeam(helper: self.managedObjectContext)
            dataTeam.id = try Data.random(size: 32).toBase64(true)
            dataTeam.json = try team.jsonData()

            let admin = DataMember(helper: self.managedObjectContext, member: creator)
            admin.isAdmin = true

            let head = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            dataTeam.head = head
            dataTeam.lastBlockHash = block.hash()
        }
    }
    
    func set(team:Team) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            dataTeam.json = try team.jsonData()
        }
    }
    
    /**
        Fetch helpers
     */
    
    //MARK: Blocks
    func fetchMainChainGenesisBlock() throws -> SigChain.SignedMessage {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataSignedMessage> = DataSignedMessage.fetchRequest()
        request.predicate = NSComparisonPredicate(
                leftExpression: NSExpression(forKeyPath: #keyPath(DataSignedMessage.previous)),
                rightExpression: NSExpression(forConstantValue: nil),
                modifier: .direct,
                type: .equalTo,
                options: NSComparisonPredicate.Options(rawValue: 0)
        )
        request.fetchLimit = 1
        
        var block:SigChain.SignedMessage?
        
        try performAndWait {
            let blocks = try self.managedObjectContext.fetch(request)
            block = try blocks.first?.toSignedMessage()
        }
        
        guard let genesisBlock = block else {
            throw Errors.noGenesisBlock
        }
        
        return genesisBlock
    }
    
    func fetchAll(limit:Int? = nil) throws -> [SigChain.SignedMessage] {
        defer { mutex.unlock() }
        mutex.lock()

        var blocks:[SigChain.SignedMessage] = []
        
        try performAndWait {
            var pointer = try self.fetchCoreDataTeam().head
            while pointer != nil {
                try blocks.append(pointer!.toSignedMessage())
                pointer = pointer?.previous
                
                if let limit = limit, blocks.count >= limit {
                    break
                }
            }
        }
        
        return blocks
    }
    
    func hasBlock(for hash:Data) throws -> Bool {
        return try self.fetchBlock(for: hash) != nil
    }
    
    func fetchBlocks(after hash:Data, limit:Int? = nil) throws -> [SigChain.SignedMessage] {
        var block = try self.fetchBlock(for: hash)
        
        defer { mutex.unlock() }
        mutex.lock()
        
        var blocks:[SigChain.SignedMessage] = []
        
        try performAndWait {
            while let pointer = block?.next {
                try blocks.append(pointer.toSignedMessage())
                block = pointer
                
                if let limit = limit, blocks.count >= limit {
                    break
                }
            }
        }
        
        return blocks
    }
    
    private func fetchBlock(for hash:Data) throws -> DataSignedMessage? {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataSignedMessage> = DataSignedMessage.fetchRequest()
        
        let blockHashPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSignedMessage.blockHash)),
            rightExpression: NSExpression(forConstantValue: hash),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [blockHashPredicate])
        
        var block:DataSignedMessage?
        
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
    
    
    //MARK: Members
    
    func fetchAll() throws -> [SigChain.Identity] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        var members:[SigChain.Identity] = []
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                try members.append($0.member())
            }
        }
        
        return members
    }
    
    func fetchAdmins() throws -> [SigChain.Identity] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let isAdminPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.isAdmin)),
            rightExpression: NSExpression(forConstantValue: true),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [isAdminPredicate])
        
        var admins:[SigChain.Identity] = []
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                try admins.append($0.member())
            }
        }
        
        return admins
    }

    func fetchMemberIdentity(for publicKey:SodiumSignPublicKey) throws -> SigChain.Identity? {
        let member = try self.fetchMember(for: publicKey)
        return try member?.member()
    }
    
    
    private func fetchMember(for publicKey:SodiumSignPublicKey) throws -> DataMember? {
        defer { mutex.unlock() }
        mutex.lock()
        
        return try self.fetchMemberUnlocked(for: publicKey)
    }
    
    private func fetchMemberUnlocked (for sodiumPublicKey:SodiumSignPublicKey) throws -> DataMember? {
        let publicKey = sodiumPublicKey.data

        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [memberPredicate])
        
        var member:DataMember?
        
        try performAndWait {
            member = try self.managedObjectContext.fetch(request).first
        }
        
        return member
    }

    
    func fetchMemberWith(email:String) throws -> SigChain.Identity? {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.email)),
            rightExpression: NSExpression(forConstantValue: email),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [memberPredicate])
        
        var member:SigChain.Identity?
        
        try performAndWait {
            member = try self.managedObjectContext.fetch(request).first?.member()
        }
        
        return member
    }

    
    func fetchDeletedMemberIdentity(for publicKey:SodiumSignPublicKey) throws -> SigChain.Identity? {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataRemovedMember> = DataRemovedMember.fetchRequest()
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataRemovedMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey.data),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [memberPredicate])
        
        var member:DataRemovedMember?
        
        try performAndWait {
            member = try self.managedObjectContext.fetch(request).first
        }
        
        return try member?.member()
    }
    
    /**
     Add/remove member
     */
    func add(member:SigChain.Identity, block:SigChain.SignedMessage) throws {
        guard try fetchMember(for: member.publicKey) == nil else {
            throw Errors.memberAlreadyExists
        }
        
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newMember = DataMember(helper: self.managedObjectContext, member: member)
            newMember.isAdmin = false
            
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            
            self.append(newHead: newHead, to: dataTeam)
        }
    }
    
    func remove(member:SodiumSignPublicKey, block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: member.data as NSData),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [memberPredicate])
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            let foundMembers = try self.managedObjectContext.fetch(request)
            
            // create a `removed member` for lookup
            if let removedIdentity = try foundMembers.first?.member() {
                let _ = DataRemovedMember(helper: self.managedObjectContext, identity: removedIdentity)
            }
            
            // remove the member
            for member in foundMembers {
                self.managedObjectContext.delete(member)
            }
            
            // add the corresponding block
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }
    }
    
    /**
     Add/remove admins
     Get admin public keys
     */
    func add(admin publicKey:SodiumSignPublicKey, block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        // first fetch the team member
        guard let adminMember = try self.fetchMemberUnlocked(for: publicKey) else {
            throw Errors.prospectiveAdminIsNotMember
        }
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            // make the member an admin
            adminMember.isAdmin = true
            
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }
    }
    
    
    func isAdmin(for publicKey:SodiumSignPublicKey) throws -> Bool {
        let admins = try self.fetchAdmins()
        return admins.filter { $0.publicKey == publicKey }.isEmpty == false
    }
    
    func remove(admin publicKey:SodiumSignPublicKey, block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataMember> = DataMember.fetchRequest()
        
        let memberPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataMember.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey.data as NSData),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [memberPredicate])
        
        try performAndWait {
            for adminToRemove in try self.managedObjectContext.fetch(request) {
                adminToRemove.isAdmin = false
            }
            
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }
        
    }

    
    //MARK: Invitations
    func fetchInvitationsFor(sodiumPublicKey:SodiumSignPublicKey) throws -> [SigChain.Invitation] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let publicKey = sodiumPublicKey.data
        var invitations = [SigChain.Invitation]()
        
        // search direct
        let directRequest:NSFetchRequest<DataDirectMemberInvitation> = DataDirectMemberInvitation.fetchRequest()
        
        let directPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataDirectMemberInvitation.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        directRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ directPredicate])

        
        // search indirect, domain
        let domainRequest:NSFetchRequest<DataDomainMemberInvitation> = DataDomainMemberInvitation.fetchRequest()
        
        let domainPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataDomainMemberInvitation.noncePublicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        domainRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [domainPredicate])
        
        
        // search indirect, individual email invites
        let individualRequest:NSFetchRequest<DataIndividualMemberInvitation> = DataIndividualMemberInvitation.fetchRequest()
        
        let individualPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataIndividualMemberInvitation.noncePublicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        individualRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [individualPredicate])
        
        try performAndWait {
            try self.managedObjectContext.fetch(directRequest).forEach {
                try invitations.append(.direct($0.invite()))
            }

            try self.managedObjectContext.fetch(domainRequest).forEach {
                try invitations.append(.indirect($0.invite()))
            }
            
            try self.managedObjectContext.fetch(individualRequest).forEach {
                try invitations.append(.indirect($0.invite()))
            }

        }

        return invitations
    }
    
    func add(invitation:SigChain.Invitation) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            switch invitation {
            case .direct(let direct):
                let _ = DataDirectMemberInvitation(helper: self.managedObjectContext, invite: direct)

            case .indirect(let indirect):
                switch indirect.restriction {
                case .domain(let domain):
                    let _ = DataDomainMemberInvitation(helper: self.managedObjectContext, invite: indirect, domain: domain)
                case .emails(let emails):
                    let _ = DataIndividualMemberInvitation(helper: self.managedObjectContext, invite: indirect, emails: emails)
                }
            }
        }

    }
    
    func removeDirectInvitations(for sodiumPublicKey:SodiumSignPublicKey) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        let publicKey = sodiumPublicKey.data
        
        // search individual email invites
        let directRequest:NSFetchRequest<DataDirectMemberInvitation> = DataDirectMemberInvitation.fetchRequest()
        
        let publicKeyPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataDirectMemberInvitation.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        
        directRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [publicKeyPredicate])
        
        try performAndWait {
            try self.managedObjectContext.fetch(directRequest).forEach {
                self.managedObjectContext.delete($0)
            }
        }
    }
    
    func removeAllInvitations() throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        // search the domain
        let domainDelete = DataDomainMemberInvitation.batchDeleteRequest()
        
        // search individual email invites
        let individualDelete = DataIndividualMemberInvitation.batchDeleteRequest()
        
        // search direct invites
        let directDelete =  DataDirectMemberInvitation.batchDeleteRequest()
        
        try performAndWait {
            try self.managedObjectContext.execute(domainDelete)
            try self.managedObjectContext.execute(individualDelete)
            try self.managedObjectContext.execute(directDelete)
        }
    }

    //MARK: Host Keys
    func fetchAll() throws -> [SSHHostKey] {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()

        var pinnedHosts = [SSHHostKey]()
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                try pinnedHosts.append($0.sshHostKey())
            }
        }
        
        return pinnedHosts
    }
    
    func isPinned(hostKey:SSHHostKey) throws -> Bool {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        
        let hostKeyPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.publicKey)),
            rightExpression: NSExpression(forConstantValue: hostKey.publicKey),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let hostNamePredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.host)),
            rightExpression: NSExpression(forConstantValue: hostKey.host),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [hostKeyPredicate, hostNamePredicate])
        
        var hasHostKey = false
        
        try performAndWait {
            let objects = try self.managedObjectContext.fetch(request)
            hasHostKey = objects.isEmpty == false
        }
        
        return hasHostKey
    }
    
    /**
        Add a new block
     */
    func append(block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            let dataTeam = try self.fetchCoreDataTeam()
            
            self.append(newHead: newHead, to: dataTeam)
        }
        
    }
    
    private func append(newHead:DataSignedMessage, to team:DataTeam) {
        let currentHead = team.head
        currentHead?.next = newHead
        team.head = newHead
        team.lastBlockHash = newHead.blockHash
    }
    
    
    /**
        Pin/Unpin/check Known Hosts
     */
    func pin(sshHostKey:SSHHostKey, block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            
            let newHost = DataSSHHostKey(helper: self.managedObjectContext)
            newHost.host = sshHostKey.host
            newHost.publicKey = sshHostKey.publicKey
            
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            
            self.append(newHead: newHead, to: dataTeam)
        }
    }
    
    /** Match verifiedHostAuth (hostName, publicKey) to a pin (host, publickey)
        - returns true if host name is pinned and public key matches
        - returns false if host name is not pinned
        - throws HostMistmatchError if host name is pinned but public key is mismatched
    */
    typealias HostIsPinned = Bool
    func check(verifiedHost:VerifiedHostAuth) throws -> HostIsPinned {
        let hostName = verifiedHost.hostname
        let hostPublicKey = verifiedHost.hostKey
        
        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        
        let hostPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.host)),
            rightExpression: NSExpression(forConstantValue: hostName),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        // look for matching hosts the with hostname `hostName`
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [hostPredicate])
        
        var sshHostKeys:[SSHHostKey] = []
        
        try performAndWait {
            for result in try self.managedObjectContext.fetch(request) {
                try sshHostKeys.append(result.sshHostKey())
            }
        }
        
        // if unknown, then it's not pinned
        guard !sshHostKeys.isEmpty else {
            return false
        }
        
        let matchingHosts = sshHostKeys.filter { $0.publicKey == hostPublicKey}
        
        guard false == matchingHosts.isEmpty
        else {
            let pinnedPublicKeys = sshHostKeys.map({ $0.publicKey })
            throw HostMistmatchError(hostName: hostName, expectedPublicKeys: pinnedPublicKeys)
        }
        
        return true
    }

    func unpin(sshHostKey:SSHHostKey, block:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataSSHHostKey> = DataSSHHostKey.fetchRequest()
        request.predicate = self.sshHostKeyEqualsPredicate(host: sshHostKey.host, publicKey: sshHostKey.publicKey.bytes)
        
        try performAndWait {
            for result in try self.managedObjectContext.fetch(request) {
                self.managedObjectContext.delete(result)
            }
            
            let dataTeam = try self.fetchCoreDataTeam()
            let newHead = DataSignedMessage(signedMessage: block, helper: self.managedObjectContext)
            self.append(newHead: newHead, to: dataTeam)
        }

    }
    
    // MARK: Logs
    func appendLog(signedMessage:SigChain.SignedMessage) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let newHead = DataLogBlock(signedMessage: signedMessage, helper: self.managedObjectContext)
            let dataTeam = try self.fetchCoreDataTeam()
            
            let currentHead = dataTeam.headLog
            currentHead?.next = newHead
            dataTeam.headLog = newHead
        }
    }
    
    func getLogEncryptionKey() throws -> SodiumSecretBoxKey? {
        defer { mutex.unlock() }
        mutex.lock()
        
        var key:SodiumSecretBoxKey?
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            key = dataTeam.logEncryptionKey?.bytes
        }

        return key
    }
    
    func setLogEncryptionKey(key: SodiumSecretBoxKey) throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        try performAndWait {
            let dataTeam = try self.fetchCoreDataTeam()
            dataTeam.logEncryptionKey = key.data
        }
    }
    
    func fetchLogChainGenesisBlock() throws -> SigChain.SignedMessage {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataLogBlock> = DataLogBlock.fetchRequest()
        request.predicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataLogBlock.previous)),
            rightExpression: NSExpression(forConstantValue: nil),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        request.fetchLimit = 1
        
        var block:SigChain.SignedMessage?
        
        try performAndWait {
            let blocks = try self.managedObjectContext.fetch(request)
            block = try blocks.first?.toSignedMessage()
        }
        
        guard let genesisBlock = block else {
            throw Errors.noLogGenesisBlock
        }
        
        return genesisBlock
    }
    
    func fetchLogBlocks(after hash:Data, limit: Int? = nil) throws -> [SigChain.SignedMessage] {
        defer { mutex.unlock() }
        mutex.lock()
        
        var block = try self.fetchLogBlockUnlocked(for: hash)
        
        var blocks:[SigChain.SignedMessage] = []
        
        try performAndWait {
            while let pointer = block?.next {
                try blocks.append(pointer.toSignedMessage())
                block = pointer

                if let limit = limit, blocks.count >= limit {
                    break
                }
            }
        }
        
        return blocks
    }
    
    
    func hasLogBlock(for hash:Data) throws -> Bool {
        return try self.fetchLogBlock(for: hash) != nil
    }
    
    private func fetchLogBlock(for hash:Data) throws -> DataLogBlock? {
        defer { mutex.unlock() }
        mutex.lock()
        
        return try self.fetchLogBlockUnlocked(for: hash)
    }
    
    private func fetchLogBlockUnlocked(for hash:Data) throws -> DataLogBlock? {
        let request:NSFetchRequest<DataLogBlock> = DataLogBlock.fetchRequest()
        
        let blockHashPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataLogBlock.blockHash)),
            rightExpression: NSExpression(forConstantValue: hash),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [blockHashPredicate])
        
        var block:DataLogBlock?
        
        try performAndWait {
            let blocks = try self.managedObjectContext.fetch(request)
            block = blocks.first
        }
        
        return block
    }
    
    func lastLogBlockHash() throws -> Data? {
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
            
            if let hash = team?.headLog?.blockHash as Data? {
                blockHash = Data(hash)
            }
        }
        
        return blockHash
    }

    
    // Unsent Audit Logs
    func createAuditLog(unsentAuditLog:UnsentAuditLog) throws {
        defer { mutex.unlock() }
        mutex.lock()

        try performAndWait {
            let _ = DataUnsentAuditLog(unsentAuditLog: unsentAuditLog, helper: self.managedObjectContext)
        }
    }

    func fetchNextUnsentAuditLog() throws -> UnsentAuditLog? {
        defer { mutex.unlock() }
        mutex.lock()
        
        let request:NSFetchRequest<DataUnsentAuditLog> = DataUnsentAuditLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(DataUnsentAuditLog.date), ascending: true)]
        request.fetchLimit = 1
        
        var unsent:UnsentAuditLog?
        
        try performAndWait {
            unsent = try self.managedObjectContext.fetch(request).first?.toUnsentAuditLog()
        }
        
        return unsent
    }
    
    func markAuditLogSent(dataHash:Data) throws {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataUnsentAuditLog> = DataUnsentAuditLog.fetchRequest()
        
        let dataHashPred = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataUnsentAuditLog.dataHash)),
            rightExpression: NSExpression(forConstantValue: dataHash),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        request.predicate = dataHashPred
        
        try performAndWait {
            try self.managedObjectContext.fetch(request).forEach {
                self.managedObjectContext.delete($0)
            }
        }
    }
    
    func clearAllUnsentAuditLogs() throws {
        defer { mutex.unlock() }
        mutex.lock()
        
        let delete = DataUnsentAuditLog.batchDeleteRequest()

        try performAndWait {
            try self.managedObjectContext.execute(delete)
        }
    }
    
    
    // MARK: Track/Fetch Public Keys that have a have a wrapped log encryption key
    func fetchTrackedPublicKeysWithWrappedLogEncryptionKey() throws -> [SodiumBoxPublicKey] {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataPublicKeyWrappedLogEncryptionTo> = DataPublicKeyWrappedLogEncryptionTo.fetchRequest()
        
        var keys:[SodiumBoxPublicKey] = []
        
        try performAndWait {
            for key in try self.managedObjectContext.fetch(request) {
                try keys.append(key.toPublicKey())
            }
        }
        
        return keys
    }
    
    func setTrackedPublicKeysForWrappedLogEncryptionKey(publicKeys:[SodiumBoxPublicKey]) throws {
        defer { mutex.unlock() }
        mutex.lock()

        let request:NSFetchRequest<DataPublicKeyWrappedLogEncryptionTo> = DataPublicKeyWrappedLogEncryptionTo.fetchRequest()

        try performAndWait {
            // delete old keys
            for existingKey in try self.managedObjectContext.fetch(request) {
                self.managedObjectContext.delete(existingKey)
            }

            // add new keys
            for key in publicKeys {
                let _ = DataPublicKeyWrappedLogEncryptionTo(helper: self.managedObjectContext, publicKey: key)
            }
        }
    }
    
    
    // MARK: Predicates
    private func sshHostKeyEqualsPredicate(host:String, publicKey:SodiumSignPublicKey) -> NSPredicate {
        let hostPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.host)),
            rightExpression: NSExpression(forConstantValue: host),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        let publicKeyPredicate = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: #keyPath(DataSSHHostKey.publicKey)),
            rightExpression: NSExpression(forConstantValue: publicKey.data as NSData),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [hostPredicate, publicKeyPredicate])
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
