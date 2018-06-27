//
//  U2FAccountsController.swift
//  Krypton
//
//  Created by Alex Grinman on 5/6/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class AccountsController:KRBaseTableController, UITextFieldDelegate {
    
    @IBOutlet var tagTextField:UITextField!
    @IBOutlet var headerView:UIView!

    enum Section:Int {
        case keys = 0
        case secured = 1
        case unsecured = 2
    }
    
    let known = KnownU2FApplication.common
    
    var secured:[U2FAppID] = []
    var unsecured:[U2FAppID] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            tagTextField.text = try IdentityManager.getMe()
        } catch (let e) {
            log("error getting me: \(e)", LogType.error)
            showWarning(title: "Error", body: "Could not get user data. \(e)")
        }
        
        self.tableView.tableHeaderView?.frame = CGRect(x: 0, y: 0, width: self.tableView.tableHeaderView?.frame.width ?? 0, height: 100)
        self.tableView.tableFooterView = UIView()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
        
        NotificationCenter.default.addObserver(self, selector: #selector(AccountsController.newLog), name: NSNotification.Name(rawValue: "new_log"), object: nil)
        
    }
    
    @objc func newLog() {
        dispatchMain { self.checkForUpdates() }
    }
    
    func checkForUpdates() {
        do {
            self.secured = try U2FAccountManager.getAllAccountsLocked().sorted(by: ({ $0.order < $1.order }))
        } catch {
            log("error getting me: \(error)", LogType.error)
            showWarning(title: "Error", body: "Could not get user data. \(error)")
        }
        

        var securedKnown = Set<KnownU2FApplication>()
        secured.map({ KnownU2FApplication(for: $0) }).forEach({
            if let known = $0 {
                securedKnown.insert(known)
            }
        })
        
        let knownSet = Set(known)
        
        let unsecured = knownSet.subtracting(securedKnown)
        
        self.unsecured = [U2FAppID]([KnownU2FApplication](unsecured).sorted(by: ({ $0.order < $1.order })).map({ $0.rawValue }))
        self.tableView.reloadData()
    }
    
    @IBAction func editNameTapped() {
        tagTextField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        headerView.setBoxShadow()
        checkForUpdates()
    }
    //MARK: TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        
        switch section {
        case .keys:
            return 1
        case .secured:
            return secured.count
        case .unsecured:
            return unsecured.count
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.layoutIfNeeded()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .keys:
            let cell = tableView.dequeueReusableCell(withIdentifier: KeyAccountCell.identifier) as! KeyAccountCell
            do {
                cell.keyLabel.text = "Default Key Pair: \(try KeyManager.sharedInstance().keyPair.publicKey.type.description)"
            } catch {
                log("\(error)", .error)
            }
            return cell

        case .secured:
            let cell = tableView.dequeueReusableCell(withIdentifier: SecuredAccountCell.identifier) as! SecuredAccountCell
            cell.set(appID: secured[indexPath.row])
            return cell
        case .unsecured:
            let cell = tableView.dequeueReusableCell(withIdentifier: UnsecuredAccountCell.identifier) as! UnsecuredAccountCell
            cell.set(appID: unsecured[indexPath.row])
            cell.delegate = self
            return cell
        }
    }
    

    //MARK: TextField Delegate -> Editing Email
    func textFieldDidBeginEditing(_ textField: UITextField) {}
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        guard let email = textField.text else {
            return false
        }
        
        if email.isEmpty {
            tagTextField.text = (try? IdentityManager.getMe()) ?? ""
        } else {
            IdentityManager.setMe(email: email)
        }
        
        textField.resignFirstResponder()
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? U2FSetupHelpController, let appID = sender as? U2FAppID {
            dest.appID = appID
        }
    }
}

class SecuredAccountCell:UITableViewCell {
    static let identifier = "SecuredAccountCell"
    @IBOutlet weak var logo:UIImageView!
    @IBOutlet weak var app:UILabel!
    @IBOutlet weak var lastUsed:UILabel!
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var card:UIView!
    @IBOutlet weak var colorView:UIView!
    @IBOutlet weak var logoConstraint:NSLayoutConstraint!
    @IBOutlet weak var logoSepConstraint:NSLayoutConstraint!

    var branding:U2FBranding?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        card.setBoxShadow()
        
    }
    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func set(appID:U2FAppID) {
        let known = KnownU2FApplication(for: appID)
        app.text = known?.displayName ?? appID.simpleDisplay
        
        if let theLogo = known?.logo {
            logo.image = theLogo
            logoConstraint.constant = 34
            logoSepConstraint.constant = 16
        } else {
            logoConstraint.constant = 0
            logoSepConstraint.constant = 0
        }
        
        if let timeAgo = U2FAccountManager.getLastUsed(account: appID)?.timeAgoLong() {
            lastUsed.text = "Last login \(timeAgo)"
        } else {
            lastUsed.text = "Never logged in"
        }
        
        checkBox.setCheckState(.checked, animated: true)
    }
}

import AVFoundation

class KeyAccountCell:UITableViewCell {
    static let identifier = "KeyAccountCell"
    
    @IBOutlet weak var keyLabel:UILabel!
    @IBOutlet weak var card:UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.setBoxShadow()
    }
}

class UnsecuredAccountCell:UITableViewCell {
    static let identifier = "UnsecuredAccountCell"

    @IBOutlet weak var logo:UIImageView!
    @IBOutlet weak var app:UILabel!
    @IBOutlet weak var card:UIView!

    var delegate:UIViewController?
    var appID:String?
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.setBoxShadow()
    }
    
    func set(appID:U2FAppID) {
        self.appID = appID
        
        let known = KnownU2FApplication(for: appID)
        app.text = known?.displayName ?? appID.simpleDisplay
        logo.image = known?.logo ?? #imageLiteral(resourceName: "web")
    }
    
    @IBAction func fixTapped() {
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()

        delegate?.performSegue(withIdentifier: "showU2FSecureAccount", sender: self.appID)
    }
}

extension U2FAppID {
    var simpleDisplay:String {
        if let host = URL(string: self)?.host {
            return host
        }
        
        return self
    }
}

class U2FSetupHelpController:KRBaseController {
    @IBOutlet weak var logo:UIImageView!
    @IBOutlet weak var app:UILabel!
    @IBOutlet weak var top:NSLayoutConstraint!

    var appID:String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let appID = appID else {
            logo.image = nil
            app.text = "unknown"
            return
        }
        
        let known = KnownU2FApplication(for: appID)
        logo.image = known?.logo
        app.text = known?.displayName ?? appID.simpleDisplay
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    @IBAction func dismissHelp() {
        self.dismiss(animated: true, completion: nil)
    }
}

