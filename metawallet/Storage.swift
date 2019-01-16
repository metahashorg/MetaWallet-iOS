//
//  TokenStorage.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 03/01/2019.
//  Copyright © 2019 MAD. All rights reserved.
//

import Foundation
import OneStore

class Storage {
    static let shared = Storage()
    init(){
        
    }
    
    private let stack = Stack(userDefaults: UserDefaults.standard, domain: "org.metahash.metawallet")
    
    var token: String? {
        get {
            let token = OneStore<String>(stack: stack, key: "token")
            return token.value
        } set {
            let token = OneStore<String>(stack: stack, key: "token")
            token.value = newValue
        }
    }
    
    var refreshToken: String? {
        get {
            let token = OneStore<String>(stack: stack, key: "refresh_token")
            return token.value
        } set {
            let token = OneStore<String>(stack: stack, key: "refresh_token")
            token.value = newValue
        }
    }
    
    var wallets: [Wallet] {
        get {
            let defaults = UserDefaults.standard
            if let savedWallets = defaults.object(forKey: "wallets") as? Data {
                let decoder = JSONDecoder()
                if let wallets = try? decoder.decode([Wallet].self, from: savedWallets) {
                    return wallets
                } else {
                    return []
                }
            } else {
                return []
            }
        } set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                let defaults = UserDefaults.standard
                defaults.set(encoded, forKey: "wallets")
            }
        }
    }
    
}
