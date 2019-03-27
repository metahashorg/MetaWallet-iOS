//
//  TokenStorage.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 03/01/2019.
//  Copyright © 2019 MAD. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper

class Storage {
    static let shared = Storage()
    init(){
        
    }
    
    var token: String? {
        get {
            let wrapper = KeychainWrapper.standard
            return wrapper.string(forKey: "token")
        } set {
            let wrapper = KeychainWrapper.standard
            if newValue == nil {
                wrapper.removeObject(forKey: "token")
                return
            }
            wrapper.set(newValue!, forKey: "token")
        }
    }
    
    var refreshToken: String? {
        get {
            let wrapper = KeychainWrapper.standard
            return wrapper.string(forKey: "refresh_token")
        } set {
            let wrapper = KeychainWrapper.standard
            if newValue == nil {
                wrapper.removeObject(forKey: "refresh_token")
                return
            }
            wrapper.set(newValue!, forKey: "refresh_token")
        }
    }
    
    var login: String {
        get {
            let wrapper = KeychainWrapper.standard
            return wrapper.string(forKey: "login") ?? "default"
        } set {
            let wrapper = KeychainWrapper.standard
            wrapper.set(newValue, forKey: "login")
        }
    }
    
    func getWallets(for currency: String) -> [Wallet] {
        let wrapper = KeychainWrapper.standard
        if let savedWallets = wrapper.data(forKey: "wallets_\(login)_\(currency)") {
            let decoder = JSONDecoder()
            if let wallets = try? decoder.decode([Wallet].self, from: savedWallets) {
                return wallets
            } else {
                return []
            }
        } else {
            return []
        }
    }
    
    func setWallets(_ wallets: [Wallet], for currency: String) {
        if wallets.isEmpty {
            return
        }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(wallets) {
            let wrapper = KeychainWrapper.standard
            wrapper.set(encoded, forKey: "wallets_\(login)_\(currency)")
        }
    }
    
}
