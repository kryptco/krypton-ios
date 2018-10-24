//
//  BackupCodesController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/29/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class BackupCodesController:KRBaseTableController {
    
    @IBOutlet weak var sectionImageView: UIImageView!
    
    var backupCodes:[OTPAuth] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.tableHeaderView?.frame = CGRect(x: 0, y: 0, width: self.tableView.tableHeaderView?.frame.width ?? 0, height: 100)
        self.tableView.tableFooterView = UIView()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
        
        sectionImageView.tintColor = UIColor.lightGray
        checkForUpdates()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.viewControllers.first?.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(BackupCodesController.addNewCodeTapped))
        checkForUpdates()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let mainController = self.navigationController?.viewControllers.first as? MainController
        self.navigationController?.viewControllers.first?.navigationItem.rightBarButtonItem = mainController?.helpButton
    }
    
    func showNewBackupCode() {
        self.tableView.reloadData()
        self.tableView.scrollToRow(at: IndexPath(row: self.backupCodes.count - 1, section: 0), at: .bottom, animated: true)
    }
    
    func checkForUpdates() {
        do {
            self.backupCodes = try OTPAuthManager.loadLocked().sorted { $0.service < $1.service || ($0.service == $1.service && $0.account < $1.account) }
        } catch {
            log("error loading backup totp codes: \(error)", .error)
            showWarning(title: "Error", body: "Could not load backup codes. \(error)")
        }
        dispatchMain {
            self.tableView.reloadData()
        }
    }

    @objc func addNewCodeTapped() {
        let scan = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "TOTPScanController") as! TOTPScanController
        scan.onFoundOTPAuth = { otpAuth in
            do {
                try OTPAuthManager.add(otpAuth: otpAuth)
            } catch {
                self.showWarning(title: "Error", body: "Could not add backup code: \(error).")
            }
            
            self.checkForUpdates()
            self.showNewBackupCode()
        }
        self.present(scan, animated: true, completion: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    //MARK: TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(backupCodes.count, 1)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.layoutIfNeeded()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !backupCodes.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: EmptyBackupCodesCell.identifier) as! EmptyBackupCodesCell
            cell.onScanTap = {
                (self.parent as? UITabBarController)?.selectedIndex = MainController.TabIndex.pair.index
            }
            
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: BackupCodeCell.identifier) as! BackupCodeCell
        cell.set(otpAuth: backupCodes[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !backupCodes.isEmpty
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .default, title: "Delete", handler: { (action, indexPath) in
            let otpAuth = self.backupCodes[indexPath.row]
            self.askConfirmationIn(title: "Delete Backup Code?",
                                   text: "Are you sure you want to delete your backup code for \(otpAuth.account) on \(otpAuth.service)" , accept: "Delete", cancel: "Cancel",
                                   handler:
                { (didConfirm) in
                    guard didConfirm else {
                        return
                    }
                    
                    do {
                        try OTPAuthManager.remove(otpAuth: otpAuth)
                        self.checkForUpdates()
                    } catch {
                        self.showWarning(title: "Error", body: "Could not delete backup code. \(error)")
                        return
                    }
                }
            )
        })]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as? BackupCodeCell
        
        if cell?.codeView.isHidden == true {
            cell?.viewCodeTapped()
        }
    }
}

class TOTPScanController: KRBaseController, KRScanDelegate {
    
    @IBOutlet weak var textView:UIView!
    
    var onFoundOTPAuth:((OTPAuth) -> ())?
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.setBoxShadow()
    }
    
    func onFound(data: String) -> Bool {
        let loading = LoadingController.present(from: self)
        
        var otpAuth:OTPAuth
        do {
            otpAuth = try OTPAuth(urlString: data)
        } catch {
            loading?.showError(hideAfter: 0.5, title: "Invalid Code", error: "This QR code is not valid. Error: \(error)")
            return false
        }
        
        loading?.showSuccess(hideAfter: 0.5) {
            self.dismiss(animated: true, completion: {
                self.onFoundOTPAuth?(otpAuth)
            })
        }
        return true
    }
    
    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scan = segue.destination as? KRScanController {
            scan.delegate = self
        }
    }
}

class BackupCodeCell:UITableViewCell {
    static let identifier = "BackupCodeCell"
    
    @IBOutlet weak var serviceLabel:UILabel!
    @IBOutlet weak var accountLabel:UILabel!
    
    @IBOutlet weak var logo:UIImageView!
    @IBOutlet weak var logoConstraint:NSLayoutConstraint!
    @IBOutlet weak var logoSepConstraint:NSLayoutConstraint!
    
    @IBOutlet weak var card:UIView!
    
    @IBOutlet weak var codeView:UIView!
    @IBOutlet weak var codeLabel:UILabel!
    @IBOutlet weak var copyButton:UIButton!
    
    @IBOutlet weak var unlockButton:UIButton!
    
    var delegate:UIViewController?
    
    var otpAuth:OTPAuth?
    
    var timer:Timer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.setBoxShadow()
    }
    
    func set(otpAuth: OTPAuth) {
        if !codeView.isHidden {
            self.hideCode()
        }

        serviceLabel.text = otpAuth.service
        accountLabel.text = otpAuth.account
        
        if let theLogo = otpAuth.service.serviceStringToLogo() {
            logo.image = theLogo
            logoConstraint.constant = 34
            logoSepConstraint.constant = 16
        } else {
            logoConstraint.constant = 0
            logoSepConstraint.constant = 0
            
            do {
                let fetcher = try TOTPCachedImageFetcher()
                try fetcher.loadImage(for: otpAuth.service) { (image) in
                    if let img = image {
                        dispatchMain {
                            self.logo.image = img
                            self.logoConstraint.constant = 34
                            self.logoSepConstraint.constant = 16
                            self.layoutIfNeeded()
                        }
                    }
                }
            } catch {
                log("failed to load image for: \(otpAuth.service) because \(error)", .error)
            }
        }
        
        self.otpAuth = otpAuth
    }
    
    @IBAction func copyCode() {
        if let code = self.codeLabel.text {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
            UIPasteboard.general.string = code
        }
        
        UIView.animate(withDuration: 0.25, animations: {
            self.codeLabel.alpha = 0
            self.unlockButton.alpha = 0
            self.copyButton.setTitleColor(UIColor.appBlack, for: .normal)
            
        }) { (_) in
            dispatchAfter(delay: 1.0, task: {
                dispatchMain {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.codeLabel.alpha = 1.0
                        self.copyButton.setTitleColor(UIColor.clear, for: .normal)
                        self.unlockButton.alpha = 1.0
                    }, completion: nil)
                }
            })
        }
    }
    
    @IBAction func viewCodeTapped() {
        if !codeView.isHidden {
            self.hideCode()
            return
        }
        
        guard let otpAuth = self.otpAuth else {
            codeLabel.text = "??????"
            return
        }
        
        do {
            let code = try otpAuth.generateCode()
            codeLabel.text = code
            self.showCode(hideIn: otpAuth.period)
            
        } catch {
            log("otp error: \(error)", .error)
            delegate?.showWarning(title: "Error", body: "Could not generate backup code: \(error)")
        }
    }
    
    func showCode(hideIn:Int) {
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        
        unlockButton.setTitle("Lock", for: .normal)
        unlockButton.layer.borderColor = UIColor.appBlack.withAlphaComponent(0.7).cgColor
        unlockButton.setTitleColor(UIColor.appBlack.withAlphaComponent(0.7), for: .normal)
        
        copyButton.setTitleColor(UIColor.clear, for: .normal)
        
        codeView.isHidden = false
        
        let _ = animateTimer(for: Double(hideIn))
        
        timer = Timer.scheduledTimer(withTimeInterval: Double(hideIn), repeats: false, block: { (_) in
            dispatchMain {
                self.hideCode()
            }
        })
    }
    
    func animateTimer(for time:Double) -> CAShapeLayer {
        // Create shape layer
        let layer = CAShapeLayer()
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: card.bounds.height))
        path.addLine(to: CGPoint(x: card.bounds.width, y: card.bounds.height))
        layer.path = path.cgPath
        
        layer.strokeStart = 0
        layer.strokeEnd = 0
        layer.lineWidth = 8
        layer.strokeColor = UIColor(hex: 0x11C56F).cgColor
        layer.fillColor = UIColor.clear.cgColor
        
        card.layer.addSublayer(layer)
        
        // animation
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = 1.0
        animation.duration = time
        
        layer.add(animation, forKey: "line")
        return layer
    }
    
    func hideCode() {
        codeView.isHidden = true
        unlockButton.setTitle("Unlock", for: .normal)
        unlockButton.layer.borderColor = UIColor(hex: 0x11C56F).cgColor
        unlockButton.setTitleColor(UIColor(hex: 0x11C56F), for: .normal)
        
        timer?.invalidate()
        timer = nil
        
        card.layer.sublayers?.forEach {
            $0.removeAllAnimations()
        }
    }
}

class EmptyBackupCodesCell:UITableViewCell {
    static let identifier = "EmptyBackupCodesCell"
    var onScanTap:(()->())?
    
    @IBAction func scanTapped() {
        self.onScanTap?()
    }
}

extension String {
    func serviceStringToLogo() -> UIImage? {
        let service = self.lowercased()
        
        switch service {
        case "google":
            return #imageLiteral(resourceName: "google")
        case "dropbox":
            return #imageLiteral(resourceName: "dropbox")
        case "facebook":
            return #imageLiteral(resourceName: "facebook")
        case "twitter":
            return #imageLiteral(resourceName: "twitter")
        case "github":
            return #imageLiteral(resourceName: "github")
        case "stripe":
            return #imageLiteral(resourceName: "stripe")
        case "gitlab":
            return #imageLiteral(resourceName: "gitlab")
        case "duoDemo":
            return #imageLiteral(resourceName: "duo")
        case "keeper":
            return #imageLiteral(resourceName: "keeper")
        case "fedora":
            return #imageLiteral(resourceName: "fedora")
        case "bitbucket":
            return #imageLiteral(resourceName: "bitbucket")
        case "sentry":
            return #imageLiteral(resourceName: "sentry")
        case "amazon web services":
            return UIImage(imageLiteralResourceName: "aws")
        default:
            return nil
        }
    }
}
