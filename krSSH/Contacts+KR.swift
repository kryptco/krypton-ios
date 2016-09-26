//
//  Contacts+KR.swift
//  krSSH
//
//  Created by Alex Grinman on 9/26/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import Foundation
import Contacts

class KRContacts {
    
    lazy var people: [CNContact] = {
        let contactStore = CNContactStore()
        let keysToFetch = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor] as [CNKeyDescriptor]
        
        // Get all the containers
        var allContainers: [CNContainer] = []
        do {
            allContainers = try contactStore.containers(matching: nil)
        } catch {
            log("error fetching containers", .error)
        }
        
        var results: [CNContact] = []
        
        // Iterate all containers and append their contacts to our results array
        for container in allContainers {
            let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            
            do {
                let containerResults = try contactStore.unifiedContacts(matching: fetchPredicate,keysToFetch: keysToFetch)
                results.append(contentsOf: containerResults)
            } catch {
                log("error fetching results for container", .error)
            }
        }
        
        return results
    }()
}
