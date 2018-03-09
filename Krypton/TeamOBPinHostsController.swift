//
//  TeamOBPinHostsController.swift
//  Krypton
//
//  Created by Alex Grinman on 12/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TeamsOnboardingPinHostsController:KRBaseTableController {
    
    @IBOutlet weak var contentView:UIView!
    @IBOutlet weak var nextButton:UIButton!
    
    @IBOutlet weak var selectedLabel:UILabel!
    
    var settings:CreateFromAppSettings!
    
    var hosts:[(SSHHostKey, Bool)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setKrLogo()
        
        for v in [contentView, nextButton] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.tableFooterView = UIView()
        
        do {
            hosts = try KnownHostManager.shared.fetchAll().map { ($0.sshHostKey(), false) }
        } catch {
            self.showWarning(title: "Error", body: "Failed to load known hosts. Please try again.")
        }
        
        selectAllTapped()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let loadController = segue.destination as? TeamLoadController
        {
            loadController.joinType = .createFromApp(self.settings)
        }
    }
    
    func reload() {
        let selected = self.hosts.filter({ $0.1 })
        self.settings.hosts = selected.map({ $0.0 })
        self.selectedLabel.text = "\(selected.count)/\(self.hosts.count) selected"
        self.tableView.reloadData()
    }
    
    @IBAction func selectAllTapped() {
        hosts = hosts.map({ return ($0.0, true)})
        self.reload()
    }
    
    //MARK: TableViewDelegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hosts.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CreatePinHostCell.identifier) as! CreatePinHostCell
        let host = hosts[indexPath.row]
        cell.set(host: host.0, isSelected: host.1)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let host = hosts[indexPath.row]
        hosts[indexPath.row] = (host.0, !host.1)
        self.reload()
    }
}

class CreatePinHostCell:UITableViewCell {
    static let identifier = "CreatePinHostCell"
    override var reuseIdentifier: String? { return CreatePinHostCell.identifier }
    
    @IBOutlet var hostNameLabel:UILabel!
    @IBOutlet var fingerprintLabel:UILabel!
    
    func set(host:SSHHostKey, isSelected:Bool) {
        hostNameLabel.text = host.host
        fingerprintLabel.text = host.publicKey.SHA256.hexPretty
        
        if isSelected {
            self.accessoryType = .checkmark
        } else {
            self.accessoryType = .none
        }
    }
    
}

