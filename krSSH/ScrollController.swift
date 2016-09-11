//
//  ScrollController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class ScrollController:UIViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var scrollView:UIScrollView!
    
    
    @IBOutlet weak var scrollButton:UIButton!

    @IBOutlet weak var topArrow:UIImageView!
    @IBOutlet weak var botArrow:UIImageView!
    @IBOutlet weak var headerView:UIView!

    
    @IBOutlet weak var meView:UIView!
    @IBOutlet weak var sessionsView:UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
            scrollButton.setImage(IGSimpleIdenticon.from(publicKey, size: CGSize(width: 50, height: 50)), for: UIControlState.normal)
            
        } catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            showWarning(title: "Error loading keypair", body: "\(e)")
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        scrollButton.setBorder(color: UIColor.clear, cornerRadius: 25, borderWidth: 25)
        scrollView.scrollRectToVisible(CGRect(origin: CGPoint(x: scrollView.contentSize.width - 1, y: scrollView.contentSize.height - 1), size: CGSize(width: 1, height: 1)), animated: true)
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let max = meView.frame.size.height
        
        let curr = ((max - scrollView.contentOffset.y)/max)
        
        topArrow.alpha = 1 - curr
        botArrow.alpha = curr
        
        
        self.tabBarController?.tabBar.alpha = 1 - curr

        log("\(curr), \(scrollView.contentOffset.y)")
        
      
        
    }
    
}
