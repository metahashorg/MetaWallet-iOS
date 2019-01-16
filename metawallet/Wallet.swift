//
//  Wallet.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 08/01/2019.
//  Copyright © 2019 MAD. All rights reserved.
//

import Foundation

struct Transaction {
    var to: String
    var value: String
    var fee: String
    var nonce: String
    var data: String
    var pubKey: String
    var sign: String
}

struct Wallet: Codable {
    let currency: String
    let currencyCode: String
    
    var password: String = ""
    var publicKey: String = ""
    var address: String = ""
    var name: String = ""
    
    var privateKeyData: Data? = nil
    var publicKeyData: Data? = nil
    
    var balance: Double = 0

    
    init(name: String, currency: String, publicKey: String? = nil, currencyCode: String, address: String? = nil, password: String = "", privateKeyData: Data? = nil, publicKeyData: Data? = nil) {
        self.name = name
        self.currency = currency
        if let publicKey = publicKey {
            self.publicKey = publicKey
        } else if let publicKeyData = publicKeyData {
             self.publicKey = WalletService.publicKeyHexString(from: publicKeyData)
        }
        self.currencyCode = currencyCode
        self.privateKeyData = privateKeyData
        self.publicKeyData = publicKeyData
        if let address = address {
            self.address = address
        } else if let publicKeyData = publicKeyData {
            self.address = WalletService.addressHexString(from: publicKeyData)
        }
        self.password = password
    }
    
    var btcKey: BTCKey? {
        return BTCKey(privateKey: privateKeyData)
    }
    
    var hasPrivateKey: Bool {
        get {
            return publicKeyData != nil
        }
    }
    
    func updateBalance(completion: @escaping (Double, Double) -> Void) {
        APIClient.shared.getWalletBalance(for: address, completion: completion)
    }
    
    func getDescription() -> [String : Any] {
        let descriptionDict = ["address" : address, "balance" : String(balance), "hasPrivateKey" : hasPrivateKey, "name" : ""] as [String : Any]
        return descriptionDict
    }
    
}
