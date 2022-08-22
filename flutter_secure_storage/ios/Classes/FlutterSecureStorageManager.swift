//
//  FlutterSecureStorageManager.swift
//  flutter_secure_storage
//
//  Created by Julian Steenbakker on 22/08/2022.
//

import Foundation

class FlutterSecureStorageManager {

    
    let baseQuery: [CFString: Any] = [kSecClass : kSecClassGenericPassword]
    
    internal func containsKey(key: String, groupId: Int?, accountName: String?, synchronizable: Bool) -> Bool {
        var keychainQuery = baseQuery
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        keychainQuery[kSecAttrAccount] = key
        keychainQuery[kSecReturnData] = true
        keychainQuery[kSecAttrSynchronizable] = synchronizable
        
        if keychainQuery[kSecAttrAccount] != nil {
            return true
        } else {
            return false
        }
    }
    
    internal func readAll(groupId: Int?, accountName: String?, synchronizable: Bool) -> [CFString: Any] {
        var keychainQuery = baseQuery
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        keychainQuery[kSecReturnData] = true
        keychainQuery[kSecMatchLimit] = kSecMatchLimitAll
        keychainQuery[kSecReturnAttributes] = true
        
        keychainQuery[kSecAttrSynchronizable] = synchronizable
        
        
        
        // SecItemCopyMatching will attempt to copy the item
         // identified by query to the reference itemCopy
         var ref: AnyObject?
         let status = SecItemCopyMatching(
            keychainQuery as CFDictionary,
             &ref
         )
        
        if (status == noErr) {
            let items = ref as! NSDictionary
            var results: [CFString: Any] = [:]
            
            items.forEach { key, value in
                let valueString = String(data: items[key] as! Data, encoding: .utf8)
                results[key as! CFString] = valueString
            }
            return results
        }

        return [:]
    }
    
    internal func read(key: String, groupId: Int?, accountName: String?, synchronizable: Bool) -> String? {
        var keychainQuery = baseQuery
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        keychainQuery[kSecReturnData] = true
        keychainQuery[kSecAttrAccount] = key
        
        keychainQuery[kSecAttrSynchronizable] = synchronizable
        
         var ref: AnyObject?
         let status = SecItemCopyMatching(
            keychainQuery as CFDictionary,
             &ref
         )
        
        var value: String? = nil
        
        if (status == noErr) {
            value = String(data: ref as! Data, encoding: .utf8)
        }

        return value
    }
    
    internal func delete(key: String, groupId: Int?, accountName: String?, synchronizable: Bool) -> Bool {
        var keychainQuery = baseQuery
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        keychainQuery[kSecReturnData] = true
        keychainQuery[kSecAttrAccount] = key
        
        keychainQuery[kSecAttrSynchronizable] = synchronizable
        
         let status = SecItemDelete(keychainQuery as CFDictionary)
        
        
        if (status == noErr) {
            return true
        }

        return false
    }
    
    internal func deleteAll(groupId: Int?, accountName: String?, synchronizable: Bool) -> Bool {
        var keychainQuery = baseQuery
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        keychainQuery[kSecAttrSynchronizable] = synchronizable
        
         let status = SecItemDelete(keychainQuery as CFDictionary)
        
        
        if (status == noErr) {
            return true
        }

        return false
    }
    
    internal func write(key: String, value: String, groupId: Int?, accountName: String?, synchronizable: Bool, accessibility: String?) -> Bool {
        var keychainQuery = baseQuery
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        keychainQuery[kSecReturnData] = true
        keychainQuery[kSecAttrAccount] = key
        keychainQuery[kSecMatchLimit] = kSecMatchLimitOne
        
        keychainQuery[kSecAttrSynchronizable] = synchronizable
        
        var attrAccessible: CFString = kSecAttrAccessibleWhenUnlocked
        if (accessibility != nil) {
            switch accessibility {
            case "passcode":
                attrAccessible = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
                break;
            case "unlocked":
                attrAccessible = kSecAttrAccessibleWhenUnlocked
                break
            case "unlocked_this_device":
                attrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                break
            case "first_unlock":
                attrAccessible = kSecAttrAccessibleAfterFirstUnlock
                break
            case "first_unlock_this_device":
                attrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                break
            default:
                attrAccessible = kSecAttrAccessibleWhenUnlocked
            }
        }
        
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, nil)

        if (status == noErr) {
            keychainQuery[kSecMatchLimit] = nil
            
            let update: [CFString: Any] = [
                kSecValueData: value,
                kSecAttrAccessible: attrAccessible,
                kSecAttrSynchronizable: synchronizable
            ]
            
            let status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)
            if (status != noErr){
                print("SecItemUpdate status = \(status)");
            }
        } else {
            keychainQuery[kSecMatchLimit] = nil
            
            let update: [CFString: Any?] = [
                kSecValueData: value,
                kSecAttrAccessible: attrAccessible,
                kSecMatchLimit: nil
            ]
            
            let status = SecItemAdd(update as CFDictionary, nil)
            if (status != noErr){
                print("SecItemUpdate status = \(status)");
            }
        }

        return false
    }

}
