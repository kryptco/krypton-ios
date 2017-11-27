//
//  PGPBlobRequestController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class PGPBlobRequestController:UIViewController {
    
    var request:Request?
    
    @IBOutlet weak var blobTextLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func set(blob:Data) {
        if let blobText = try? blob.utf8String() {
            blobTextLabel.text = blobText
        } else {
            blobTextLabel.text = "Binary data (\(blob.count) bytes)\nSHA-256 digest: \(blob.SHA256.hexPretty.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))"
        }
    }
}
