//
//  ExchangeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/27/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import UIKit

enum ExchangeState:Int {
    case Scan = 0, Key = 1
}
class ExchangeController: UIViewController, KRScanDelegate {

    var state = ExchangeState.Scan
    
    @IBOutlet weak var qrImageView:UIImageView!
    @IBOutlet weak var blurView:UIView!

    var scanViewController:KRScanController?
    var qrImage:UIImage?
    
    // stored properties

    
    @IBOutlet var segmentedControl:UISegmentedControl!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        self.showScanningMode()

    }
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.barTintColor = UIColor.appColor()

        self.qrImage = nil
        self.qrImageView.setBorder(UIColor.appColor(), cornerRadius: 20.0, borderWidth: 0)
        
        if self.segmentedControl.selectedSegmentIndex == ExchangeState.Scan.rawValue {
            self.scanViewController?.canScan = true
        }
    }
    
    var shouldShowProfile = true
    override func viewDidAppear(animated: Bool) {
        let value = UIInterfaceOrientation.Portrait.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
        super.viewDidAppear(animated)
        
        if TARGET_IPHONE_SIMULATOR == 1 && shouldShowProfile {
            shouldShowProfile = false
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let scanner = segue.destinationViewController as? KRScanController {
            self.scanViewController = scanner
            scanner.delegate = self
        }
    }

    func showScanningMode() {
        self.state = .Scan
        self.segmentedControl.selectedSegmentIndex = self.state.rawValue

        self.scanViewController?.view.hidden = false
        self.scanViewController?.canScan = true
        self.qrImageView.hidden = true
        
        UIView.animateWithDuration(0.3) { () -> Void in
            self.blurView.alpha = 0
        }
    }
    
    func showKeyMode() {
        self.state = .Key
        self.segmentedControl.selectedSegmentIndex = self.state.rawValue
        self.scanViewController?.canScan = false

        if let qr = self.qrImage {
            self.qrImageView.image = qr
        }
        else if let img = RSCode128Generator(codeTable: .auto).generateCode("testing123", machineReadableCodeObjectType: AVMetadataObjectTypeCode128Code) {
            self.qrImage = img
            self.qrImageView.image = img

        }
        
        self.qrImageView.hidden = false
        
        UIView.animateWithDuration(0.3) { () -> Void in
            self.blurView.alpha = 1.0
        }
    }


    @IBAction func changeModes(sender:UISegmentedControl) {
        if sender.selectedSegmentIndex == ExchangeState.Scan.rawValue {
            self.showScanningMode()
        } else if sender.selectedSegmentIndex == ExchangeState.Key.rawValue {
            self.showKeyMode()
        }
    }
    
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {

        return false
    }

}






