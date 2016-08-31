//
//  KRScanController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 1/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import AudioToolbox

protocol KRScanDelegate {
    func onFound(data:String) -> Bool
}

class KRScanController: RSCodeReaderViewController {
    
    var delegate:KRScanDelegate?
    
    private var _canScan:Bool = true
    var canScan:Bool {
        get { return _canScan }
        set(val) {
            
//            if val {
//                self.session.startRunning()
//            } else {
//                self.session.stopRunning()
//            }
            _canScan = val
        }
    }
        
    var presenter:UIViewController? {
        return self.parentViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.focusMarkLayer.strokeColor = UIColor.redColor().CGColor
        self.cornersLayer.strokeColor = UIColor.flatEmeraldColor().CGColor
        self.cornersLayer.strokeWidth = 6.0

        if self.output.availableMetadataObjectTypes.contains({$0 as? String ?? "" == AVMetadataObjectTypeQRCode}) {
            self.output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        }
        
        self.barcodesHandler = { barcodes in
            guard self.canScan else {
                return
            }
            
            if let data = barcodes.first?.stringValue {
                let didDecode = self.delegate?.onFound(data) ?? false
                self.canScan = !didDecode
                
                if didDecode {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                }

            }
        }
    }
}
