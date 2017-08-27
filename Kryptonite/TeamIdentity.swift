//
//  Identity.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/20/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import Sodium
import JSON

struct TeamIdentity:Jsonable {
    let id:String
    var email:String
    let keyPair:SodiumKeyPair
    let dataManager:TeamDataManager
    
    private let teamID:String
    let teamPublicKey:SodiumPublicKey
    let teamAdminSeed:Data?
    
    /**
        Team Persistance
     */
    private var _team:Team
    var team:Team {
        get { return _team }
    }
    
    mutating func set(team:Team) throws {
        try dataManager.set(team: team)
        _team = team
    }

    func commitTeamChanges() throws {
        try dataManager.saveContext()
    }
    
    func rollbackTeamChanges() throws {
        dataManager.rollbackContext()
    }
    
    /**
        Create a new identity with an email for use with `team`
     */
    static func newAdmin(email:String, teamName:String) throws -> TeamIdentity {
        let adminSeed = try Data.random(size: KRSodium.shared().sign.SeedBytes)
        
        guard let adminKeyPair = try KRSodium.shared().sign.keyPair(seed: adminSeed) else {
            throw CryptoError.generate(.Ed25519, nil)
        }

        return try TeamIdentity.new(email: email, teamPublicKey: adminKeyPair.publicKey, adminSeed: adminSeed, teamName: teamName)
    }

    static func new(email:String, teamPublicKey:SodiumPublicKey, adminSeed:Data? = nil, teamName:String = "") throws -> TeamIdentity {
        let id = try Data.random(size: 32).toBase64()
        let teamID = try Data.random(size: 32).toBase64()

        guard let keyPair = try KRSodium.shared().sign.keyPair() else {
            throw CryptoError.generate(KeyType.Ed25519, nil)
        }
        
        let team = Team(info: Team.Info(name: teamName))
        
        return try TeamIdentity(id: id, email: email, keyPair: keyPair, teamID: teamID, teamPublicKey: teamPublicKey, adminSeed: adminSeed, team: team)
    }
    
    private init(id:String, email:String, keyPair:SodiumKeyPair, teamID:String, teamPublicKey:SodiumPublicKey, adminSeed:Data? = nil, team:Team) throws {
        self.id = id
        self.email = email
        self.keyPair = keyPair
        self.teamID = teamID
        self.teamPublicKey = teamPublicKey
        self.teamAdminSeed = adminSeed
        self.dataManager = TeamDataManager(teamID: teamID)
        self._team = team
    }
    
    init(json: Object) throws {
        let adminSeed:Data? = try? ((json ~> "team_seed") as String).fromBase64()
        
        let teamID:String = try json ~> "team_id"
        
        try self.init(id: json ~> "id",
                      email: json ~> "email",
                      keyPair: SodiumKeyPair(publicKey: ((json ~> "pk") as String).fromBase64(),
                                             secretKey: ((json ~> "sk") as String).fromBase64()),
                      teamID: teamID,
                      teamPublicKey: ((json ~> "team_pk") as String).fromBase64(),
                      adminSeed: adminSeed,
                      team: TeamDataManager(teamID: teamID).fetchTeam())
    }
    
    var object: Object {
        var obj = ["id": id,
                   "email": email,
                   "pk": keyPair.publicKey.toBase64(),
                   "sk": keyPair.secretKey.toBase64(),
                   "team_id": teamID,
                   "team_pk": teamPublicKey.toBase64()]
        
        if let adminSeed = teamAdminSeed {
            obj["team_seed"] = adminSeed.toBase64()
        }
        
        return obj
    }
    
    /**
        Team admin
     */
    func adminKeyPair() throws -> SodiumKeyPair? {
        guard let seed = teamAdminSeed else {
            return nil
        }
        
        return try KRSodium.shared().sign.keyPair(seed: seed)
    }
    
    var isAdmin:Bool {
        return (try? adminKeyPair()) != nil
    }


}
