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
    var currency: String
}

class Wallet: Codable {
    let currency: String
    let currencyCode: String
    
    var password: String = ""
    var publicKey: String = ""
    var address: String = ""
    var name: String = ""
    
    var privateKeyData: Data? = nil
    var readablePrivateKey: String? = nil
    var publicKeyData: Data? = nil
    
    var balance: Double = 0
    var currentDelegate: Double?

    
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
        if privateKeyData != nil {
            readablePrivateKey = BTCHexFromData(KeyFormatter.derPrivateKey(BTCKey(privateKey: privateKeyData!)))
        }
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
            return privateKeyData != nil && privateKeyData?.count ?? 0 > 0
        }
    }
    
    func updateBalance(completion: @escaping (Double, Int, Double) -> Void) {
        APIClient.shared.getWalletBalance(for: address, currency: currency, completion: completion)
    }
    
    func getDescription() -> [String : Any] {
        let delegate = currentDelegate != nil ? String(format: "%.6", currentDelegate!) : String(format: "%.6", 0.0)
        let descriptionDict = ["address" : address, "balance" : String(balance), "hasPrivateKey" : hasPrivateKey, "name" : name, "currentDelegate" : delegate] as [String : Any]
        return descriptionDict
    }
    
}

func mergeWallets(remoteWallets: inout [Wallet], localWallets: [Wallet]) {
    var localWallets = localWallets
    for i in 0..<remoteWallets.count {
        let wallet = remoteWallets[i]
        if let savedWalletIndex = localWallets.index(where: { (savedWallet) -> Bool in
            return savedWallet.address == wallet.address
        }) {
            let savedWallet = localWallets[savedWalletIndex]
            wallet.publicKeyData = savedWallet.publicKeyData
            wallet.privateKeyData = savedWallet.privateKeyData
            if savedWallet.privateKeyData != nil {
                wallet.readablePrivateKey = BTCHexFromData(KeyFormatter.derPrivateKey(BTCKey(privateKey: savedWallet.privateKeyData!)))
            }
            wallet.password = savedWallet.password
            wallet.name = savedWallet.name
            localWallets.remove(at: savedWalletIndex)
        }
    }
    remoteWallets.append(contentsOf: localWallets)
}
