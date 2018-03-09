//
//  TeamKnownHostsController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamKnownHostsController: KRBaseTableController {
    
    var identity:TeamIdentity!
    var hosts:[SSHHostKey] = []
    var unpinned:[SSHHostKey] = []

    var isAdmin:Bool {
        return (try? identity.dataManager.withTransaction { try identity.isAdmin(dataManager: $0) }) ?? false
    }
    
    enum Section:Int {
        case pinned = 0
        case unpinned = 1
        
        init?(for indexPath:IndexPath) {
            guard let section = Section(rawValue: indexPath.section) else {
                return nil
            }
            
            self = section
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        self.title = "Pinned Hosts"
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
        
        // load the hosts
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
    }
    
    func loadData() {
    
        self.hosts = (try? self.identity.dataManager.withTransaction { return try $0.fetchAll() }) ?? self.hosts

        let knownHostsSystem:[SSHHostKey] = (try? KnownHostManager.shared.fetchAll().map({ $0.sshHostKey() })) ?? []

        var pinnedMapIndex:[String:SSHHostKey] = [:]
        hosts.forEach {
            pinnedMapIndex[$0.host] = $0
        }
        
        var unpinnedHosts:[SSHHostKey] = []
        for host in knownHostsSystem {
            if let pinned = pinnedMapIndex[host.host], pinned == host {
                continue
            }
            
            unpinnedHosts.append(host)
        }
        
        self.unpinned = unpinnedHosts
        
        dispatchMain {
            self.tableView.reloadData()
        }
    }
    
    func onCopy(host:SSHHostKey) {
        var hostAuthorizedKey:String
        do {
            hostAuthorizedKey = try "\(host.host) \(host.publicKey.toAuthorized())"
        } catch {
            self.showWarning(title: "Error Reading Host Public Key", body: "\(error)")
            return
        }
        
        let share = UIActivityViewController(activityItems: [hostAuthorizedKey],
                                             applicationActivities: nil)
        
        
        present(share, animated: true, completion: nil)
    }
    
    /// TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if unpinned.isEmpty {
            return 1
        }
        
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch Section(rawValue: section) {
        case .some(.pinned):
            return hosts.count
            
        case .some(.unpinned):
            return unpinned.count

        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .some(.unpinned):
            return "Not yet pinned known hosts"
            
        default:
            return nil
        }

    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(for: indexPath) else {
            return UITableViewCell()
        }
        
        switch section {
        case .pinned:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SSHHostKeyCell") as! SSHHostKeyCell
            let host = hosts[indexPath.row]
            cell.set(host: host, isAdmin: isAdmin)
            cell.doReload = { self.tableView.reloadData() }
            cell.onCopy = { self.onCopy(host: host) }
            cell.onRemove = {
                self.run(syncOperation: {
                    let (service, _) = try TeamService.shared().appendToMainChainSync(for: .unpinHostKey(host))
                    try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                }, title: "Unpin SSH Host Key", onSuccess: {
                    self.loadData()
                })
            }

            
            return cell

            
        case .unpinned:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SSHUnpinnedHostKeyCell") as! SSHUnpinnedHostKeyCell
            let host = unpinned[indexPath.row]
            cell.doReload = { self.tableView.reloadData() }
            cell.set(host: host, isAdmin: isAdmin)

            cell.onPin = {
                self.run(syncOperation: {
                    let (service, _) = try TeamService.shared().appendToMainChainSync(for: .pinHostKey(host))
                    try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                }, title: "Pin SSH Host Key", onSuccess: {
                    self.loadData()
                })
            }

            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = Section(for: indexPath), case .pinned =  section else {
            return false
        }

        if isAdmin {
            return true
        }
        
        return false
    }
    
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Unpin"
    }
    
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            let host = hosts[indexPath.row]
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .unpinHostKey(host))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
            }, title: "Unpin SSH Host Key", onSuccess: {
                tableView.deleteRows(at: [indexPath], with: .right)
            })
            
        } else if editingStyle == .insert {
            return
        }
    }
}

class SSHHostKeyCell:UITableViewCell {
    @IBOutlet weak var hostLabel:UILabel!
    @IBOutlet weak var keyLabel:UILabel!
    @IBOutlet weak var hashLabel:UILabel!
    
    @IBOutlet weak var detailButton:UIButton!
    @IBOutlet weak var bottomContraint:NSLayoutConstraint!
    
    @IBOutlet weak var pinButton:UIButton!

    var onRemove:(()->())?
    var onCopy:(()->())?
    var doReload:(()->())?
    
    enum State {
        case initial
        case detail
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        bottomContraint.priority = UILayoutPriority(rawValue: 999)
    }
    
    var state = State.initial
    
    func set(host:SSHHostKey, isAdmin:Bool = true) {
        pinButton.isHidden = !isAdmin
        
        hostLabel.text = host.host
        hashLabel.text = "SHA256:\(host.publicKey.SHA256.toBase64())"
        keyLabel.text = (try? host.publicKey.toAuthorized()) ?? host.publicKey.toBase64()
    }
    
    func switchState(to state:State) {
        switch state {
        case .initial:
            detailButton.setTitle("Details", for: .normal)
            bottomContraint.priority = UILayoutPriority(rawValue: 999)
            
        case .detail:
            detailButton.setTitle("Hide", for: .normal)
            bottomContraint.priority = UILayoutPriority(rawValue: 1)
        }
        
        self.state = state
    }
    
    @IBAction func detailTapped() {
        switch self.state {
        case .initial:
            switchState(to: .detail)
        case .detail:
            switchState(to: .initial)
        }
        
        UIView.animate(withDuration: 1.0, animations: { self.layoutIfNeeded() })
        self.doReload?()
    }
    
    @IBAction func removeTapped() {
        onRemove?()
    }
    
    @IBAction func copyTapped() {
        onCopy?()
    }
}

class SSHUnpinnedHostKeyCell:SSHHostKeyCell {
    var onPin:(()->())?

    @IBAction func pinTapped() {
        onPin?()
    }
}




