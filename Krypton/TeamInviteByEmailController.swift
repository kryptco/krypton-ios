//
//  TeamInviteByEmailController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/15/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import ContactsUI
import Contacts
import MessageUI

class TeamInviteEmailCell:UITableViewCell {
    @IBOutlet weak var emailLabel:UILabel!
}

class TeamInviteByEmailController:KRBaseController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, CNContactPickerDelegate {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var createButton:UIButton!
    @IBOutlet weak var createView:UIView!
    @IBOutlet weak var addButton:UIButton!

    @IBOutlet weak var tableView:UITableView!
    @IBOutlet weak var pickButtonHeight:NSLayoutConstraint!

    var emails:[String] = []
    
    var contactStore = CNContactStore()
    var allContacts:[String] = []
    var filteredContacts:[String] = []

    var shouldSearchContacts:Bool = false
    
    enum ListState {
        case selected
        case filtered
    }
    
    var showState:ListState {
        if shouldSearchContacts && nameTextField.isEditing {
            return .filtered
        }
        
        return .selected
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setKrLogo()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.tableFooterView = UIView()

        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        createButton.layer.shadowOpacity = 0.175
        createButton.layer.shadowRadius = 3
        createButton.layer.masksToBounds = false
        
        createView.layer.shadowColor = UIColor.black.cgColor
        createView.layer.shadowOffset = CGSize(width: 0, height: 0)
        createView.layer.shadowOpacity = 0.175
        createView.layer.shadowRadius = 3
        createView.layer.masksToBounds = false
        
        nameTextField.isEnabled = true
        
        setCreate(valid: false)
        
        if CNContactStore.authorizationStatus(for: .contacts) ==  .authorized {
            self.shouldSearchContacts = true
            self.fetchContacts()
            self.pickButtonHeight.constant = 0
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    func setCreate(valid:Bool) {
        
        if valid {
            self.addButton.alpha = 1
            self.addButton.isEnabled = true
        } else {
            self.addButton.alpha = 0.5
            self.addButton.isEnabled = false
        }
    }
    
    func fetchContacts() {
        var allContainers: [CNContainer] = []
        do {
            allContainers = try contactStore.containers(matching: nil)
        } catch {
            log("error fetching containers: \(error)", .error)
        }
        
        var results: [CNContact] = []
        
        // Iterate all containers and append their contacts to our results array
        for container in allContainers {
            let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            
            do {
                let containerResults = try contactStore.unifiedContacts(matching: fetchPredicate, keysToFetch: [CNContactEmailAddressesKey] as [CNKeyDescriptor] )
                results.append(contentsOf: containerResults)
            } catch {
                log("error fetching results: \(error)", .error)
            }
        }
        
        var allContactsMap:[String:Bool] = [:]
        
        results.forEach { contact in
            contact.emailAddresses.map{ $0.value as String }.forEach {
                allContactsMap[$0] = true
            }
        }
        
        self.allContacts = [String](allContactsMap.keys)
        self.filteredContacts = []
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if CNContactStore.authorizationStatus(for: .contacts) !=  .authorized {
            
            contactStore.requestAccess(for: CNEntityType.contacts) { (success, err) in
                guard success else {
                    log("error loading contacts: \(String(describing: err))", .error)
                    return
                }
                
                self.pickButtonHeight.constant = 0
                self.shouldSearchContacts = true
                self.fetchContacts()
            }
        }
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let text = textField.text ?? ""
        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        setCreate(valid: !txtAfterUpdate.isEmpty && txtAfterUpdate.isValidEmail)
        filterByPrefix(prefix: txtAfterUpdate)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if let email = textField.text, email.isValidEmail {
            self.addTapped()
            return true
        }
        
        return false
    }
    
    func filterByPrefix(prefix:String) {
        self.filteredContacts = self.allContacts.filter {
            $0.contains(prefix)
        }
        
        self.tableView.reloadData()
    }
    

    
    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func contactsTapped() {
        let cnPicker = CNContactPickerViewController()
        cnPicker.delegate = self
        cnPicker.displayedPropertyKeys = [CNContactEmailAddressesKey]
        cnPicker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
        cnPicker.predicateForSelectionOfContact = NSPredicate(format: "emailAddresses.@count == 1")
        cnPicker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'emailAddresses'")
        
        self.present(cnPicker, animated: true, completion: nil)
    }

    
    @IBAction func addTapped() {
        guard let email = nameTextField.text else {
            return
        }
        
        self.emails.append(email)
        nameTextField.text = ""
        nameTextField.resignFirstResponder()
        self.tableView.reloadData()
    }
    
    @IBAction func createLinkTapped() {
        guard emails.isEmpty == false else {
            self.showWarning(title: "Error", body: "You have not selected any emails yet.")
            return
        }
        
        var inviteLink:String?

        self.run(syncOperation: {
            let (service, response) = try TeamService.shared().appendToMainChainSync(for: .indirectInvite(.emails(self.emails)))
            inviteLink = response.data?.inviteLink
            try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
        }, title: "Create Team Invite Link", onSuccess: {
            dispatchMain {
                
                if  let identity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity,
                    let name = (try? identity.dataManager.withTransaction { try $0.fetchTeam().name }),
                    let link = inviteLink
                {
                    let text = Properties.invitationText(for: name)
        
                    let message = "How would you like to share the invitation to join team \(name)?"
                    let sheet = UIAlertController(title: "Share", message: message, preferredStyle: .actionSheet)
                    
                    sheet.addAction(UIAlertAction(title: "Email", style: UIAlertActionStyle.default, handler: { (action) in
                        self.sendByEmail(me: identity.email, recipients: self.emails, teamName: name, text: text, link: link)
                    }))
                    
                    sheet.addAction(UIAlertAction(title: "Other", style: UIAlertActionStyle.default, handler: { (action) in
                        self.presentShareActivity(link: link, text: text)
                    }))
                    
                    self.present(sheet, animated: true, completion: nil)
                }

                
                
            }
        })

    }
    
    // MARK: Email
    func sendByEmail(me:String, recipients:[String], teamName:String, text:String, link:String) {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = self
        controller.navigationBar.tintColor = UIColor.app
        
        controller.setToRecipients([me])
        controller.setBccRecipients(recipients)
        controller.setSubject("Join team \(teamName) on \(Properties.appName)")
        
        if let html = Properties.invitationHTML(for: teamName, link: link) {
            controller.setMessageBody(html, isHTML: true)
        } else {
            let textAndLink = "\(text)\n\(link)"
            controller.setMessageBody(textAndLink, isHTML: false)
        }


        self.present(controller, animated: true, completion: nil)
    }
    
    override func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        if let error = error {
            self.showWarning(title: "Error Sending Invite", body: "\(error)")
            return
        }
        
        
        controller.dismiss(animated: true) {
            self.dismiss(animated: true, completion: nil)
        }
        
    }
    
    
    func presentShareActivity(link:String, text:String) {
        var items:[Any] = []
        items.append(text)
        
        if let urlItem = URL(string: link) {
            items.append(urlItem)
        }
        
        let share = UIActivityViewController(activityItems: items,
                                             applicationActivities: nil)
        
        
        share.completionWithItemsHandler = { (_, _, _, _) in
            self.dismiss(animated: true, completion: nil)
        }
        
        self.present(share, animated: true, completion: nil)
    }
    
    // MARK: Contacts
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        guard let email = contactProperty.value as? String else {
            return
        }
        emails.append(email)
        self.tableView.reloadData()
    }
    
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        
    }
    
    func didSelectContacts(_ contacts:[CNContact]) {
        contacts.forEach { contact in
            guard let email = contact.emailAddresses.first?.value as String? else {
                return
            }
            
            emails.append(email)
        }
        
        self.tableView.reloadData()
    }
    
    //MARK: TableView
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch showState {
        case .selected:
            return emails.count
        case .filtered:
            return filteredContacts.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch showState {
        case .selected:
            if emails.isEmpty {
                return nil
            }
            
            return "Chosen Emails"
        case .filtered:
            if filteredContacts.isEmpty {
                return "Type to search contacts..."
            }
            return "Searching Contacts"
        }

    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        
        switch showState {
        case .selected:
            header.textLabel?.textColor = UIColor.app
        case .filtered:
            header.textLabel?.textColor = UIColor.appBlack
        }

        
        header.textLabel?.font = Resources.appFont(size: 16, style: .regular)
        header.contentView.backgroundColor = UIColor.white
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamInviteEmailCell") as! TeamInviteEmailCell
        
        switch showState {
        case .selected:
            cell.emailLabel.text = emails[indexPath.row]
            cell.emailLabel.textColor = UIColor.black
        case .filtered:
            cell.emailLabel.text = filteredContacts[indexPath.row]
            cell.emailLabel.textColor = UIColor.app
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch showState {
        case .selected:
            return true
        case .filtered:
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Remove"
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch showState {
        case .selected:
            return
        case .filtered:
            let email = filteredContacts[indexPath.row]
            emails.append(email)
            
            // remove to not add the same twice
            if let index = self.allContacts.index(of: email) {
                self.allContacts.remove(at: index)
            }
            
            self.nameTextField.text = ""
            self.nameTextField.resignFirstResponder()
            self.setCreate(valid: false)
            self.filteredContacts = []
            self.tableView.reloadData()
        }

    }
    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.emails.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .right)

        } else if editingStyle == .insert {
            return
        }
    }
}
