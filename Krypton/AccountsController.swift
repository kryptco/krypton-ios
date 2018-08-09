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
    
    var keys:[PublicKey] = []
    var secured:[U2FAppID] = []
    var unsecured:[U2FAppID] = []

    override func viewDidLoad() {
        super.viewDidLoad()
            
        tagTextField.text = UIDevice.current.name

        do {
            tagTextField.text = try IdentityManager.getMe()
        } catch (let e) {
            log("error getting me: \(e)", LogType.error)
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
            self.keys = [try KeyManager.sharedInstance().keyPair.publicKey]

        } catch KeyManager.Errors.keyDoesNotExist {
            // no keypair
        } catch {
            log("error loading key pair: \(error)", LogType.error)
            showWarning(title: "Error", body: "Could not load key pair. \(error)")
        }
        
        // user hidden
        let hidden = UserDefaults.group?.stringArray(forKey: "u2f_account_hide_array") ?? []
        var hiddenKnown = Set<KnownU2FApplication>()
        hidden.map({ KnownU2FApplication(for: $0) }).forEach({
            if let known = $0 {
                hiddenKnown.insert(known)
            }
        })

        
        do {
            let secured = try U2FAccountManager.getAllAccountsLocked().sorted(by: ({ $0.order < $1.order }))
            self.secured = [U2FAppID](Set(secured).subtracting(Set(hidden)))
            
        } catch KeychainStorageError.notFound {
            self.secured = []
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

        let unsecured = knownSet.subtracting(securedKnown).subtracting(hiddenKnown)
        
        self.unsecured = [U2FAppID]([KnownU2FApplication](unsecured).sorted(by: ({ $0.order < $1.order })).map({ $0.rawValue }))
        
        if hidden.isEmpty {
            self.tableView.tableFooterView = UIView()
        } else {
            let button = UIButton(type: UIButtonType.system)
            button.setTitle("Show Hidden", for: .normal)
            button.setTitleColor(UIColor.appBlueGray, for: .normal)
            button.setTitleColor(UIColor.appBlueGray.withAlphaComponent(0.5), for: .highlighted)
            button.titleLabel?.font = Resources.appFont(size: 14, style: .regular)
            button.addTarget(self, action: #selector(AccountsController.deleteHidden), for: .touchUpInside)
            button.frame.size = CGSize(width: 0, height: 30)
            self.tableView.tableFooterView = button
        }
        
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
            return keys.count
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
            cell.keyLabel.text = keys[indexPath.row].type.prettyDescription
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
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = Section(rawValue: indexPath.section) else {
            return false
        }
        
        switch section {
        case .keys:
            return false
        case .secured, .unsecured:
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let section = Section(rawValue: indexPath.section) else {
            return nil
        }
        
        let hide = {(app:U2FAppID) in
            var hidden = UserDefaults.group?.stringArray(forKey: "u2f_account_hide_array") ?? []
            hidden.append(app)
            UserDefaults.group?.set(hidden, forKey: "u2f_account_hide_array")
            dispatchMain { self.checkForUpdates() }
        }
        
        switch section {
        case .keys:
            return nil
        case .secured:
            return [UITableViewRowAction(style: .default, title: "Hide", handler: { (action, indexPath) in
                let secured = self.secured[indexPath.row]
                hide(secured)
            })]

        case .unsecured:
            return [UITableViewRowAction(style: .default, title: "Hide", handler: { (action, indexPath) in
                let unsecured = self.unsecured[indexPath.row]
                hide(unsecured)
            })]
        }

    }
    
    
    @objc func deleteHidden() {
        UserDefaults.group?.removeObject(forKey: "u2f_account_hide_array")
        dispatchMain { self.checkForUpdates() }
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

