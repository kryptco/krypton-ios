//
//  PeerEmptyController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/1/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import ContactsUI

class PeerEmptyController:KRBaseController, CNContactPickerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard PeerManager.shared.all.isEmpty else {
            dismiss(animated: true, completion: nil)
            return
        }
    }
    
    //MARK: Scan Tapped
    
    @IBAction func scanTapped() {
        (self.parent?.parent as? UITabBarController)?.selectedIndex = 1
    }

    
    //MARK: Request Flow
    
    @IBAction func requestTapped() {
        
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self;
        contactPicker.navigationController?.navigationBar.tintColor = UIColor.white
        contactPicker.navigationController?.navigationBar.barTintColor = UIColor.app
        contactPicker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
        
        // 1 phone & 0 email - OR - 0 phone & 1 email
        contactPicker.predicateForSelectionOfContact =
            NSPredicate(format: "(phoneNumbers.@count == 1 &&  emailAddresses.@count == 0) || phoneNumbers.@count == 0 &&  emailAddresses.@count == 1")
        
        present(contactPicker, animated: true, completion: nil)
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        if let phoneNumber = contactProperty.value as? CNPhoneNumber {
            picker.dismiss(animated: true, completion: {
                self.present(self.smsRequest(for: phoneNumber.stringValue.sanitizedPhoneNumber()), animated: true, completion: nil)
            })
        }
        else if let email = contactProperty.value as? String {
            picker.dismiss(animated: true, completion: {
                self.present(self.emailRequest(for: email), animated: true, completion: nil)
            })
        }
        
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if let phoneNumber = contact.phoneNumbers.first?.value {
            picker.dismiss(animated: true, completion: {
                self.present(self.smsRequest(for: phoneNumber.stringValue.sanitizedPhoneNumber()), animated: true, completion: nil)
            })
        }
        else if let email = contact.emailAddresses.first?.value as? String {
            picker.dismiss(animated: true, completion: {
                self.present(self.emailRequest(for: email), animated: true, completion: nil)
            })
        }
        
    }

}
