//
//  TeamDetailController.swift
//  Krypton
//
//  Created by Alex Grinman on 7/22/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit
import LocalAuthentication
import SafariServices

class TeamDetailController: KRBaseTableController, KRTeamDataControllerDelegate, UITextFieldDelegate, TeamInviteModalDelegate {
    
    @IBOutlet weak var teamTextField:UITextField!
    
    @IBOutlet weak var linkButton:UIButton!
    @IBOutlet weak var linkButtonHeight:NSLayoutConstraint!
    @IBOutlet weak var linkButtonSpacer:NSLayoutConstraint!

    @IBOutlet weak var editTeamButton:UIButton!
    @IBOutlet weak var editApprovalIntervalButton:UIButton!

    @IBOutlet weak var emailLabel:UILabel!
    @IBOutlet weak var headerView:UIView!
    
    @IBOutlet weak var activityDetailLabel:UILabel!
    @IBOutlet weak var membersDetailLabel:UILabel!
    @IBOutlet weak var hostsDetailLabel:UILabel!

    @IBOutlet weak var approvalWindowAttributeLabel:UILabel!
    @IBOutlet weak var approvalWindowTextField:UITextField!
    
    @IBOutlet weak var logginLabel:UILabel!
    @IBOutlet weak var logginSwitch:UISwitch!

    @IBOutlet weak var adminBadge:UIView!
    
    @IBOutlet weak var billingView:UIView!
    @IBOutlet weak var tierLabel:UIButton!
    @IBOutlet weak var upgradeButton:UIButton!
    
    @IBOutlet weak var usageMembers:UILabel!
    @IBOutlet weak var usageHosts:UILabel!
    @IBOutlet weak var usageLogs:UILabel!
    
    @IBOutlet weak var limitMembers:UILabel!
    @IBOutlet weak var limitHosts:UILabel!
    @IBOutlet weak var limitLogs:UILabel!

    let warningColor = UIColor(hex: 0xF8A843);
    let purpleAccent = UIColor(hex: 0x666EE8);
    
    let mutex = Mutex()
    
    var _teamIdentity:TeamIdentity!
    let teamIdentityMutex = Mutex()
    
    var identity: TeamIdentity {
        get {
            teamIdentityMutex.lock()
            defer { teamIdentityMutex.unlock() }
            
            return _teamIdentity
        } set (id) {
            teamIdentityMutex.lock()
            defer { teamIdentityMutex.unlock() }

            _teamIdentity = id
        }
    }

    var team:Team?
    var isAdmin:Bool = false
    
    var blocks:[SigChain.SignedMessage] = []
    var members:[SigChain.Identity] = []
    var hosts:[SSHHostKey] = []
    
    let refreshInterval:TimeInterval = 10.0
    
    var currentBillingInfo:SigChainBilling.BillingInfo?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor.app
        refresh.addTarget(self, action: #selector(TeamDetailController.doFetchTeamUpdates), for: UIControlEvents.valueChanged)
        tableView.refreshControl = refresh
        
        teamTextField.delegate = self
        approvalWindowTextField.isEnabled = false
        
        if  let billingJson = UserDefaults.group?.data(forKey: "cached_billing_info_\(identity.initialTeamPublicKey.toBase64(true))"),
            let billing:SigChainBilling.BillingInfo = try? SigChainBilling.BillingInfo(jsonData: billingJson)
        {
            self.currentBillingInfo = billing
        }
        
        try? self.identity.dataManager.withTransaction {
            try self.didUpdateTeamIdentityMainThread(dataManager: $0)
        }

        self.fetchTeamUpdates()
    }
    
    @IBAction func dismissToTeamsHome(segue:UIStoryboardSegue) {}
    
    /// table view
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        return (!isAdmin && cell.reuseIdentifier == "TeamBillingCell") ? 0 :  super.tableView(tableView, heightForRowAt: indexPath)

    }

    @objc dynamic func doFetchTeamUpdates() {
        self.fetchTeamUpdates()
    }
    
    func didUpdateTeamIdentity() {
        dispatchMain {
            do {
                try self.identity.dataManager.withTransaction {
                    try self.didUpdateTeamIdentityMainThread(dataManager: $0)
                }
            } catch {
                self.showWarning(title: "Error fetching team", body: "\(error)")
            }
        }
    }
    
    override func run(syncOperation: @escaping (() throws -> Void), title: String, onSuccess: (() -> Void)? = nil, onError: (() -> Void)? = nil) {
        super.run(syncOperation: {
            try syncOperation()
        }, title: title, onSuccess: {
            onSuccess?()
        }) {
            onError?()
        }
    }
    
    func didUpdateTeamIdentityMainThread(dataManager:TeamDataManager) throws {
        tableView.refreshControl?.endRefreshing()
        
        let team = try dataManager.fetchTeam()
        
        self.teamTextField.text = team.name
        self.approvalWindowTextField.text = team.policy.description
        self.logginSwitch.isOn = team.commandEncryptedLoggingEnabled
        self.logginLabel.text = team.commandEncryptedLoggingEnabled ? "Enabled" : "Disabled"
        self.team = team
        
        self.emailLabel.text = self.identity.email
        
        self.isAdmin = try dataManager.isAdmin(for: self.identity.publicKey)
        
        if self.isAdmin {
            self.adminBadge.isHidden = false
            self.editTeamButton.isHidden = false
            self.editApprovalIntervalButton.isHidden = false
            self.logginSwitch.isHidden = false
            self.linkButtonHeight.constant = 50.0
            self.linkButtonSpacer.constant = 40.0
            
        } else {
            self.adminBadge.isHidden = true
            self.editTeamButton.isHidden = true
            self.editApprovalIntervalButton.isHidden = true
            self.logginSwitch.isHidden = true
            self.linkButtonHeight.constant = 0.0
            self.linkButtonSpacer.constant = 0.0
        }
        
        // pre-fetch team lists
        self.blocks = try dataManager.fetchAll()
        self.members = try dataManager.fetchAll()
        self.hosts = try dataManager.fetchAll()
        
        // set activity label
        let blocksCount = self.blocks.count
        let blocksSuffix = blocksCount == 1 ? "" : "s"
        self.activityDetailLabel.text = "\(blocksCount) event\(blocksSuffix)"
        
        let membersCount = self.members.count
        let membersSuffix = membersCount == 1 ? "" : "s"
        self.membersDetailLabel.text = "\(membersCount) member\(membersSuffix)"
        
        let hostsCount = self.hosts.count
        let hostsSuffix = hostsCount == 1 ? "" : "s"
        self.hostsDetailLabel.text = "\(hostsCount) pinned public-key\(hostsSuffix)"
        
        self.updateViewForCurrentBillingInfo()
        
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        for v in [headerView, billingView] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(TeamDetailController.newTeamDataNotification), name: Constants.NotificationType.newTeamsData.name, object: nil)

        if !UserDefaults.standard.bool(forKey: "new_team_invite_helper") && isAdmin && members.count == 1 {
            let firstInvite = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamInviteOBController") as! TeamInviteOBController
            firstInvite.modalTransitionStyle = .crossDissolve
            firstInvite.modalPresentationStyle = .overCurrentContext
            firstInvite.handler = {
                self.inviteLinkTapped()
            }
            self.navigationController?.present(firstInvite, animated: true, completion: nil)
            
            UserDefaults.standard.set(true, forKey: "new_team_invite_helper")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: Constants.NotificationType.newTeamsData.name, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let header = tableView.tableHeaderView {
            let newSize = header.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
            
            if header.frame.size.height != newSize.height {
                header.frame.size.height = newSize.height
                tableView.tableHeaderView = header
                tableView.layoutIfNeeded()
            }
        }
        
    }

    
    @objc func newTeamDataNotification() {
        if let updatedTeamIdentity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity {
            self.update(identity: updatedTeamIdentity)
            self.didUpdateTeamIdentity()
        }
    }
        
    /// KRTeamDataControllerDelegate
    
    var controller: UIViewController {
        return self
    }
    
    func update(identity: TeamIdentity) {
        self.identity = identity
    }
    
    func update(billingInfo: SigChainBilling.BillingInfo) {
        self.currentBillingInfo = billingInfo
        try? UserDefaults.group?.set(billingInfo.jsonData(), forKey: "cached_billing_info_\(identity.initialTeamPublicKey.toBase64(true))")
    }
    
    // MARK: Billing Helpers
    func updateViewForCurrentBillingInfo() {
        guard let currentBillingInfo = self.currentBillingInfo else {
            tierLabel.setTitle("FREE", for: .normal)
            tierLabel.setBorder(color: UIColor.black, cornerRadius: tierLabel.layer.cornerRadius, borderWidth: tierLabel.layer.borderWidth)
            upgradeButton.setTitle("Upgrade", for: .normal)

            usageMembers.text = "--"
            usageHosts.text = "--"
            usageLogs.text = "--"
            
            limitMembers.textColor = UIColor.black
            limitHosts.textColor = UIColor.black
            limitLogs.textColor = UIColor.black
            

            return
        }
        
        tierLabel.setTitle(currentBillingInfo.currentTier.name.uppercased(), for: .normal)
        
        // usage
        let toUsageText = { (usage:UInt64) -> String in
            if usage > 1000 {
                return "\(usage/1000)k"
            }
            
            return "\(usage)"
        }
        
        usageMembers.text = toUsageText(currentBillingInfo.usage.members)
        usageHosts.text = toUsageText(currentBillingInfo.usage.hosts)
        usageLogs.text = toUsageText(currentBillingInfo.usage.logsLastThirtyDays)

        
        // limits
        let toLimitText = { (limit:UInt64?) -> String in
            if let limit = limit{
                if limit > 1000 {
                    return "\(limit/1000)k"
                }
                return "\(limit)"
            }
            
            return "∞"
        }

        limitMembers.text = toLimitText(currentBillingInfo.currentTier.limit?.members)
        limitHosts.text = toLimitText(currentBillingInfo.currentTier.limit?.hosts)
        limitLogs.text = toLimitText(currentBillingInfo.currentTier.limit?.logsLastThirtyDays)

        limitMembers.textColor = UIColor.black
        limitHosts.textColor = UIColor.black
        limitLogs.textColor = UIColor.black

        usageMembers.textColor = currentBillingInfo.isWarningMembers() ? warningColor : UIColor.black;
        usageHosts.textColor = currentBillingInfo.isWarningHosts() ? warningColor : UIColor.black;
        usageLogs.textColor = currentBillingInfo.isWarningLogs() ? warningColor : UIColor.black;
        
        if currentBillingInfo.currentTier.price > 0 {
            tierLabel.setBorder(color: UIColor.app, cornerRadius: tierLabel.layer.cornerRadius, borderWidth: tierLabel.layer.borderWidth)
            tierLabel.setTitleColor(UIColor.app, for: .normal)
            upgradeButton.setTitle("Manage Billing", for: .normal)
            
            upgradeButton.backgroundColor = UIColor.white
            upgradeButton.setBorder(color: purpleAccent, cornerRadius: upgradeButton.layer.cornerRadius, borderWidth: 1.0)
            upgradeButton.setTitleColor(purpleAccent, for: .normal)

        } else {
            tierLabel.setBorder(color: warningColor, cornerRadius: tierLabel.layer.cornerRadius, borderWidth: tierLabel.layer.borderWidth)
            tierLabel.setTitleColor(warningColor, for: .normal)
            upgradeButton.setTitle("Upgrade", for: .normal)
            
            upgradeButton.backgroundColor = purpleAccent
            upgradeButton.setTitleColor(UIColor.white, for: .normal)
        }
        
    }
    
    @IBAction func planUpgradeTapped() {
        var isPaid = false

        if let currentBillingInfo = self.currentBillingInfo {
         // set isPaid
            isPaid = currentBillingInfo.currentTier.price > 0
        }
        
        if !isPaid {
            if let team = self.team, let url = URL(string: Properties.billingURL(for: team.name,
                                                                                 teamInitialPublicKey: _teamIdentity.initialTeamPublicKey,
                                                                                 adminPublicKey: _teamIdentity.publicKey,
                                                                                 adminEmail: _teamIdentity.email))
            {
                self.present(SFSafariViewController(url: url), animated: true, completion: nil)
            }

        } else {
            self.showWarning(title: "Coming Soon...", body: "Viewing in-Krypton payment history will be available in an upcoming release. Please email support@krypt.co with any billing questions.")
        }
    }
    
    //MARK: Edit
    
    /// name
    @IBAction func editTeamNameTapped() {
        self.teamTextField.isEnabled = true
        self.teamTextField.becomeFirstResponder()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        guard let name = textField.text?.trim(), let team = self.team else {
            return false
        }
        
        guard name.isValidName else {
            return false
        }
        
        guard name != team.name else {
            textField.resignFirstResponder()
            return true
        }
        
        self.askConfirmationIn(title: "Change team name?", text: "Are you sure you want to change the team name to \"\(name)\"?", accept: "Yes", cancel: "Cancel")
        { (didConfirm) in
            
            guard didConfirm else {
                self.teamTextField.text = team.name
                return
            }
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: RequestableTeamOperation.setTeamInfo(SigChain.TeamInfo(name: name)))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()

            }, title: "Change Team Name")
            
            
            self.teamTextField.resignFirstResponder()
        }
        
        return true
    }
    
    
    /// approval
    
    var datePicker:UIDatePicker? = nil
    
    @IBAction func editApprovalInterviewTapped() {
        datePicker = UIDatePicker()
        approvalWindowTextField.inputView = datePicker
        
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        toolbar.backgroundColor = UIColor.white
        toolbar.isTranslucent = false
        
        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(TeamDetailController.valueChanged))
        doneButton.tintColor = UIColor.app
        
        let removeButton = UIBarButtonItem(title: "Unset", style: UIBarButtonItemStyle.done, target: self, action: #selector(TeamDetailController.unsetApprovalWindow))
        removeButton.tintColor = UIColor.reject

        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        toolbar.setItems([removeButton, flexSpace, doneButton], animated: true)
        approvalWindowTextField.inputAccessoryView = toolbar
        
        datePicker?.datePickerMode = .countDownTimer
        datePicker?.countDownDuration = TimeInterval(self.team?.policy.temporaryApprovalSeconds ?? 0)
        datePicker?.backgroundColor  = UIColor.white
        
        self.approvalWindowTextField.isEnabled = true
        self.approvalWindowTextField.becomeFirstResponder()
    }
    
    @objc dynamic func unsetApprovalWindow() {
        self.approvalWindowTextField.isEnabled = false
        let chosenPolicy = SigChain.Policy(temporaryApprovalSeconds: nil)
        self.approvalWindowTextField.text = "unset"

        self.askConfirmationIn(title: "Unset approval window?", text: "Are you sure you want to unset the auto-approval window for all team members?", accept: "Yes", cancel: "Cancel")
        { (didConfirm) in
            
            guard didConfirm else {
                self.approvalWindowTextField.text = self.team?.policy.description ?? "<error>"
                return
            }
            
            self.approvalWindowTextField.resignFirstResponder()
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: RequestableTeamOperation.setPolicy(chosenPolicy))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()
            }, title: "Unset Auto-Approve Policy ")
        }
    }

    @objc dynamic func valueChanged() {
        guard let picker = datePicker else {
            return
        }
        
        self.approvalWindowTextField.isEnabled = false
        let chosenPolicy = SigChain.Policy(temporaryApprovalSeconds: SigChain.UTCTime(picker.countDownDuration))
        self.approvalWindowTextField.text = chosenPolicy.description

        self.askConfirmationIn(title: "Change approval window?", text: "Are you sure you want to change the auto-approval window to \"\(chosenPolicy.description)\" for all team members?", accept: "Yes", cancel: "Cancel")
        { (didConfirm) in
            
            guard didConfirm else {
                self.approvalWindowTextField.text = self.team?.policy.description ?? "<error>"
                return
            }
            
            self.approvalWindowTextField.resignFirstResponder()

            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: RequestableTeamOperation.setPolicy(chosenPolicy))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()
            }, title: "Auto-Approve Policy ")
            
        }
    }
    
    //MARK: Invitations
    
    @IBAction func inviteLinkTapped() {
        let controller = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamInviteModalController") as! TeamInviteModalController
        controller.modalTransitionStyle = .coverVertical
        controller.modalPresentationStyle = .overCurrentContext
        controller.domain = self._teamIdentity.email.getEmailDomain()
        controller.delegate = self
        self.present(controller, animated: true, completion: nil)
    }
    
    func selected(option: TeamInviteModalOption) {
        switch option {
        case .teamDomainLink:
            guard let domain = self._teamIdentity.email.getEmailDomain() else {
                self.showWarning(title: "Error", body: "Couldn't parse email address domain name.")
                return
            }
            
            self.domainOnlyLinkTapped(for: domain)

        case .individualsLink:
            self.individualLinkTapped()
            
        case .inPerson:
            self.inPersonTapped()
            
        case .other:
            let message = "Additonal options for inviting team members."
            
            let sheet = UIAlertController(title: "Add new team members", message: message, preferredStyle: .actionSheet)
            
            sheet.addAction(UIAlertAction(title: "Custom Team Email Domain-only Link", style: UIAlertActionStyle.default, handler: { (action) in
                self.customDomainOnlyLinkTapped()
            }))
            
            sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
            }))

            self.present(sheet, animated: true, completion: nil)

        }
    }
    
    func domainOnlyLinkTapped(for domain:String) {
        let message = "New team members with a @\(domain) email address can use this link to join your team."
        
        let sheet = UIAlertController(title: "@\(domain)-only Invite Link? ", message: message, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Create", style: UIAlertActionStyle.default, handler: { (action) in
            
            var inviteLink:String?
            self.run(syncOperation: {
                let (service, response) = try TeamService.shared().appendToMainChainSync(for: .indirectInvite(.domain(domain)))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()
                inviteLink = response.data?.inviteLink
                
            }, title: "Create Team Invite Link", onSuccess: {
                if let link = inviteLink {
                    self.showSharingUI(for: link)
                }
            })
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)
    }
    
    func customDomainOnlyLinkTapped() {
        let controller = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamCustomDomainInviteController") as! TeamCustomDomainInviteController
        self.present(controller, animated: true, completion: nil)
        
    }

    func individualLinkTapped() {
        let controller = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamInviteByEmailController") as! TeamInviteByEmailController
        self.present(controller, animated: true, completion: nil)
    }
    
    func inPersonTapped() {
        let controller = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamAdminInPersonQRController") as! TeamAdminInPersonQRController
        controller.identity = self._teamIdentity
        self.present(controller, animated: true, completion: nil)

    }

    func showSharingUI(for link:String) {
        // if we have a link show the link copy ui
        guard  let name = team?.name,
            isAdmin
        else {
            return
        }

        var items:[Any] = []
        items.append(Properties.invitationText(for: name))
        
        if let urlItem = URL(string: link) {
            items.append(urlItem)
        }
        
        let share = UIActivityViewController(activityItems: items,
                                             applicationActivities: nil)
        
        
        present(share, animated: true, completion: nil)

    }
    
    @IBAction func editInviteLinkTapped() {
        let message = "New team members will no longer be able to join your team with existing links you've created."
        
        let sheet = UIAlertController(title: "Close open invitation links?", message: message, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Close Invitations", style: UIAlertActionStyle.destructive, handler: { (action) in
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .closeInvitations)
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()

            }, title: "Close Invitations")
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)

    }
    
    
    //MARK: Logging
    
    @IBAction func loggingSwitchChangedValue() {
        // ensure settings changed
        guard team?.commandEncryptedLoggingEnabled != logginSwitch.isOn else {
            return
        }
        
        // turn logging off
        guard logginSwitch.isOn else {
            
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .removeLoggingEndpoint(.commandEncrypted))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()

            }, title: "Disable Audit Logs", onError: {
                self.logginSwitch.isOn = true
            })

            return
        }
        
        let message = "Enable audit logging for your team? You and other admins of the team will be able to view team members' SSH, Git, and other access logs in real-time. Krypt.co does NOT have access to these logs (they're encrypted only to you and other admins)."
        
        let sheet = UIAlertController(title: "TEAM AUDIT LOGGING", message: message, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Enable", style: UIAlertActionStyle.destructive, handler: { (action) in
            self.run(syncOperation: {
                let (service, _) = try TeamService.shared().appendToMainChainSync(for: .addLoggingEndpoint(.commandEncrypted))
                try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                self.update(identity: service.teamIdentity)
                self.didUpdateTeamIdentity()

            }, title: "Enable Audit Logs", onError: {
                self.logginSwitch.isOn = false
            })
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)
    }
    

    //MARK:  Leave Team
    @IBAction func moreSettingsTapped() {
        let sheet = UIAlertController(title: "More options", message: nil, preferredStyle: .actionSheet)
        
        if self.isAdmin {
            sheet.addAction(UIAlertAction(title: "Close all invitations", style: UIAlertActionStyle.destructive, handler: { (action) in
                self.editInviteLinkTapped()
            }))
        }
        
        sheet.addAction(UIAlertAction(title: "Leave Team", style: UIAlertActionStyle.destructive, handler: { (action) in
            self.leaveTeamTapped()
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)
    }
    
    @IBAction func leaveTeamTapped() {
        
        var team:Team
        
        do {
            team = try self.identity.dataManager.withTransaction { return try $0.fetchTeam() }
        } catch {
            self.showWarning(title: "Error fetching team", body: "\(error)")
            return
        }
        
        let message = "You will no longer have access to the team's data and your team admin will be notified that you are leaving the team. Are you sure you want to continue?"
        
        let sheet = UIAlertController(title: "Do you want to leave the \(team.name) team?", message: message, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Leave Team", style: UIAlertActionStyle.destructive, handler: { (action) in
            self.leaveTeamRequestAuth()
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)

    }
    
    func leaveTeamRequestAuth() {
        authenticate { (yes) in
            guard yes else {
                return
            }
            
            self.run(syncOperation: {
                let _ = try TeamService.shared().appendToMainChainSync(for: .leave)
                try IdentityManager.removeTeamIdentity()

            }, title: "Leave Team", onSuccess: {
                dispatchMain {
                    self.performSegue(withIdentifier: "showLeaveTeam", sender: nil)
                }

            }, onError: {
                try? IdentityManager.removeTeamIdentity()
                dispatchMain {
                    self.performSegue(withIdentifier: "showLeaveTeam", sender: nil)
                }

            })
        }
    }
    
    func authenticate(completion:@escaping (Bool)->Void) {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        let reason = "Leave the \(self.team?.name ?? "") team?"
        
        var err:NSError?
        guard context.canEvaluatePolicy(policy, error: &err) else {
            log("cannot eval policy: \(err?.localizedDescription ?? "unknown err")", .error)
            completion(true)
            
            return
        }
        
        
        dispatchMain {
            context.evaluatePolicy(policy, localizedReason: reason, reply: { (success, policyErr) in
                completion(success)
            })
        }
        
    }


    /// TableView

    enum Cell:String {
        case hosts = "hosts"
        case activity = "activity"
        case members = "members"
        
        var segue:String {
            switch self {
            case .hosts:
                return "showTeamKnownHosts"
            case .activity:
                return "showTeamActivity"
            case .members:
                return "showTeamMembers"
            }
        }
        
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cellID = tableView.cellForRow(at: indexPath)?.reuseIdentifier,
              let cell = Cell(rawValue: cellID)
        else {
            log("no such cell action id")
            return
        }
        
        self.performSegue(withIdentifier: cell.segue, sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let activityController = segue.destination as? TeamActivityController {
            activityController.blocks = self.blocks
            activityController.identity = self.identity
        } else if let membersController = segue.destination as? TeamMemberListController {
            membersController.members = self.members
            membersController.identity = self.identity
        } else if let hostsController = segue.destination as? TeamKnownHostsController {
            hostsController.hosts = self.hosts
            hostsController.identity = self.identity
        }
    }
}



class TeamInviteOBController:KRBaseController {
    
    @IBOutlet weak var blurView:UIView!
    @IBOutlet weak var cornerView:UIView!
    @IBOutlet weak var shareButton:UIButton!

    @IBOutlet weak var tipHeight:NSLayoutConstraint!
    
    var handler:(()->())?

    override func viewDidLoad() {
        super.viewDidLoad()
        tipHeight.constant = 0.0
        
        for v in [blurView, shareButton] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }
    }
    @IBAction func inviteTapped() {
        self.dismiss(animated: true) {
            self.handler?()
        }
    }
    
    @IBAction func skipTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        UIView.animate(withDuration: 1.0) {
            self.tipHeight.constant = 100.0
            self.view.layoutIfNeeded()
        }
    }
}

extension SigChainBilling.BillingInfo {
    
    func isWarningMembers() -> Bool {
        guard let limit = self.currentTier.limit?.members
        else {
            return false
        }
        
        return SigChainBilling.BillingInfo.nearLimit(usage: usage.members, limit: limit)
    }
    
    func isWarningHosts() -> Bool {
        guard let limit = self.currentTier.limit?.hosts
        else {
            return false
        }
        
        return SigChainBilling.BillingInfo.nearLimit(usage: usage.hosts, limit: limit)
    }
    
    func isWarningLogs() -> Bool {
        guard let limit = self.currentTier.limit?.logsLastThirtyDays
        else {
            return false
        }
        
        return SigChainBilling.BillingInfo.nearLimit(usage: usage.logsLastThirtyDays, limit: limit)
    }


    static func nearLimit(usage:UInt64, limit:UInt64) -> Bool {
        return usage > limit/2
    }
}
