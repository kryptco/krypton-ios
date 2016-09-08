
//
//  UIViewController+KR.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/16/15.
//  Copyright (c) 2015 KryptCo.LLC. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    func showWarning(title:String, body:String, then:(()->Void)? = nil) {
        dispatchMain {
            
            let alertController:UIAlertController = UIAlertController(title: title, message: body,
                                                                      preferredStyle: UIAlertControllerStyle.alert)
            
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction!) -> Void in
                    then?()
                }))
            
            self.present(alertController, animated: true, completion: nil)
            
        }
    }
    
    func askConfirmationIn(title:String, text:String, accept:String, cancel:String, handler: @escaping ((_ confirmed:Bool) -> Void)) {
        
        let alertController:UIAlertController = UIAlertController(title: title, message: text, preferredStyle: UIAlertControllerStyle.alert)
        
        
        alertController.addAction(UIAlertAction(title: accept, style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            handler(true)
            
        }))
        
        alertController.addAction(UIAlertAction(title: cancel, style: UIAlertActionStyle.cancel, handler: { (action:UIAlertAction) -> Void in
            
            handler(false)
            
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }

}

extension UIViewController {
    
    func findTopViewController() -> UIViewController? {
        
        if let tabbed = self as? UITabBarController {
            return tabbed.selectedViewController?.findTopViewController()
        }
        else if let nav = self as? UINavigationController {
            return nav.visibleViewController?.findTopViewController()
        }
        
        return self
    }
}



