//
//  SuccessController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit

class SuccessController: UIViewController {

    var duration:TimeInterval = 1.5
    
    var resultImage:UIImage? = ResultImage.check.image
    var shouldSpin = false
    var hudText = ""

    @IBOutlet weak var spinner:UIActivityIndicatorView!
    @IBOutlet weak var titleLabel:UILabel!
    @IBOutlet weak var resultImageView:UIImageView!

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        spinner.hidesWhenStopped = true
        if shouldSpin {
            spinner.startAnimating()
        }
        
        titleLabel.text = hudText
        resultImageView.image = resultImage

        guard !shouldSpin else {
            return
        }
        
        dispatchAfter(delay: duration) { 
            dispatchMain {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
