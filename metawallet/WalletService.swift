//
//  KeyService.swift
//  BitcoinAddress
//
//  Created by Андрей Зубехин on 05.03.2018.
//  Copyright © 2018 Андрей Зубехин. All rights reserved.
//

import Foundation
import SwiftyJSON

class WalletService {
    
    static let shared = WalletService()
    
    var txInfo = ["id":"",
                  "proxy":["wait","wait","wait"],
                  "stage":1,
                  "torrent":["wait","wait","wait"]
        ] as [String : Any]
    
    func resetTxInfo() {
        txInfo = ["id":"",
                  "proxy":["wait","wait","wait"],
                  "stage":1,
                  "torrent":["wait","wait","wait"]
            ] as [String : Any]
    }

    static func generateNewWallet(currencyId: String, currencyCode: String, password: String, name: String) -> Wallet? {
        guard let btcKey = BTCKey.init() else {
            return nil
        }
        let wallet = Wallet.init(name: name, currency: currencyId, currencyCode: currencyCode, password: password, privateKeyData: btcKey.privateKey as Data, publicKeyData: btcKey.publicKey as Data)
        var wallets = Storage.shared.getWallets(for: currencyId)
        wallets.append(wallet)
        Storage.shared.setWallets(wallets, for: currencyId)
        return wallet
    }
    
    static func getPrivateKeyString(address: String, password: String) -> String {
        guard let wallet = Storage.shared.getWallets().first(where: { (wallet) -> Bool in
            return wallet.address == address && wallet.privateKeyData != nil
        }) else {
            return "NO_PRIVATE_KEY_FOUND"
        }
        if wallet.password != password && wallet.password != "" {
            return "WRONG_PASSWORD"
        }
        let key = BTCKey(privateKey: wallet.privateKeyData)!
        var dataString = ""
        if password != "" {
            guard let encryptedPEMData = KeyFormatter.encrypt(key, password: wallet.password) else {
                return "NO_PRIVATE_KEY_FOUND"
            }
            dataString = String(data: encryptedPEMData, encoding: .utf8) ?? "NO_PRIVATE_KEY_FOUND"
        } else {
            dataString = BTCHexFromData(KeyFormatter.derPrivateKey(key))
        }
        return dataString
    }
    
    static func createTransaction(address: String, password: String, to: String, amount: String, fee: String, data: String, currency: String, initialized: @escaping (String) -> Void, check: @escaping (String) -> Void, completion: @escaping (String?) -> Void, error: @escaping (String) -> Void) {
        guard let wallet = Storage.shared.getWallets(for: currency).first(where: { (wallet) -> Bool in
            return wallet.address == address && wallet.privateKeyData != nil && wallet.currency == currency
        }) else {
            error("NO_PRIVATE_KEY_FOUND")
            return
        }
        if wallet.password != password && wallet.password != "" {
            error("WRONG_PASSWORD")
            return
        }
        shared.txInfo = ["id":"",
                  "proxy":["wait","wait","wait"],
                  "stage":1,
                  "torrent":["wait","wait","wait"]
        ]
        wallet.updateBalance { (balance, spent) in
            let nonce = spent + 1
            let dataHexString = BTCHexFromData(data.data(using: .utf8)!)!
            let signatureMessage = generateSignatureMessage(to: to, value: amount, nonce: String(nonce), fee: fee, data: data).lowercased()
            let messageData = signatureMessage.dataWithHexString()
            let signature = Hashing.sign(messageData, with: wallet.btcKey!)!
            let signatureString = BTCHexFromData(signature)!
            let publicKeyHex = publicKeyHexString(from: wallet.publicKeyData!).lowercased()
            
            let transaction = Transaction.init(to: to, value: amount, fee: fee, nonce: String(nonce), data: dataHexString, pubKey: publicKeyHex, sign: signatureString, currency: currency)
            
            let initUpdate = try! String.init(data: JSONSerialization.data(withJSONObject: shared.txInfo, options: .sortedKeys), encoding: .utf8)!
            initialized(initUpdate)
            
            APIClient.shared.sendTransaction(transaction: transaction, updateStatus: {
                let updateString = try! String.init(data: JSONSerialization.data(withJSONObject: shared.txInfo, options: .sortedKeys), encoding: .utf8)!
                check(updateString)
            }, completion: {
                APIClient.shared.checkTransaction(transactionHash: shared.txInfo["id"] as! String, currency: transaction.currency, updateStatus: {
                    let updateString = try! String.init(data: JSONSerialization.data(withJSONObject: shared.txInfo, options: .sortedKeys), encoding: .utf8)!
                    check(updateString)
                }, completion: {
                    completion(nil)
                })
            })
        }
    }
    
    static func importPrivateKeyWalletFromString(key: String) -> String {
        var keyObject: BTCKey?
        keyObject = KeyFormatter.createKey(fromDERString: key)
        guard let gottenKey = keyObject else {
            return "Error"
        }
        let address = addressHexString(from: gottenKey.publicKey as Data)
        return address
    }
    
    
    static func importWallet(with privateKey: String, name: String, password: String, currencyId: String, currencyName: String, completion: @escaping (String) -> Void) {
        var keyObject: BTCKey?
        //"yuy,4,MHC,Qqq"
        if privateKey.contains("-----BEGIN EC PRIVATE KEY-----") {
            keyObject = KeyFormatter.decryptKey(privateKey, withPassword: password)
        } else {
            keyObject = KeyFormatter.createKey(fromDERString: privateKey)
        }
        
        guard let key = keyObject else {
            completion("Error")
            return
        }
        
        let privateKeyDERString = BTCHexFromData(KeyFormatter.derPrivateKey(key))
        if privateKeyDERString?.starts(with: "307702") ?? false {
            completion("INCORRECT_KEY")
            return
        }
        let address = addressHexString(from: key.publicKey as Data)
        var wallets = Storage.shared.getWallets(for: currencyId)
        if let loadedWalletIndex = wallets.firstIndex(where: { (wallet) -> Bool in
            return wallet.address == address
        }) {
            wallets[loadedWalletIndex].privateKeyData = key.privateKey! as Data
            wallets[loadedWalletIndex].readablePrivateKey = BTCHexFromData(KeyFormatter.derPrivateKey(key))
            wallets[loadedWalletIndex].publicKeyData = key.publicKey! as Data
            wallets[loadedWalletIndex].name = name
            Storage.shared.setWallets(wallets, for: currencyId)
            completion(address)
        } else {
            let wallet = Wallet.init(name: name, currency: currencyId, currencyCode: currencyName, password: password, privateKeyData: key.privateKey as Data, publicKeyData: key.publicKey as Data)
            var wallets = Storage.shared.getWallets(for: currencyId)
            wallets.append(wallet)
            Storage.shared.setWallets(wallets, for: currencyId)
            APIClient.shared.syncWallet(wallet: wallet, completion: { (_, _) in
                completion(address)
            })
        }
    }
    
    
    static func encryptedPemKey(wallet: Wallet, withPassword: String) -> String {
        let encryptedData = KeyFormatter.encrypt(wallet.btcKey!, password: withPassword)
        let string = String.init(data: encryptedData!, encoding: .utf8)!
        
        print(string)
        return string
    }

    static func addressHexString(from publicKeyData: Data) -> String {
        let btcKey = BTCKey(publicKey: publicKeyData)
        let data = btcKey?.publicKey as Data?
        let hash256 = BTCSHA256(data)
        let ripemd = BTCRIPEMD160(hash256! as Data)
        let zeros = 0x00
        ripemd?.replaceBytes(in: NSMakeRange(0, 0), withBytes: UnsafeRawPointer.init(bitPattern: zeros), length: 1)
        let ripemdHash = BTCSHA256(ripemd! as Data)
        let anotherRipemdHash = BTCSHA256(ripemdHash! as Data)
        ripemd?.append((anotherRipemdHash?.bytes)!, length: 4)
        let hexAddress = BTCHexFromData(ripemd! as Data)
        return "0x" + hexAddress!
    }
    
    static func publicKeyHexString(from publicKeyData: Data) -> String {
        let btcKey = BTCKey(publicKey: publicKeyData)
        return "0x" + BTCHexFromData(KeyFormatter.derPublicKey(btcKey))
    }
    
    static func privateKeyHexString(from privateKeyData: Data) -> String {
        let btcKey = BTCKey(privateKey: privateKeyData)
        return "0x" + BTCHexFromData(KeyFormatter.derPrivateKey(btcKey))
    }
    
    static func generateSignatureMessage(to: String, value: String, nonce: String,
                                         fee: String, data: String) -> String {
        var result = ""

        result.append(to.replacingOccurrences(of: "0x", with: ""))
        result.append(intToLittleEndianString(value: Int(value)!))
        result.append(intToLittleEndianString(value: Int(fee)!))
        result.append(intToLittleEndianString(value: Int(nonce)!))
        result.append(intToLittleEndianString(value: 0))
        
        return result

    }
    
    static func intToLittleEndianString(value: Int) -> String {
        var returnString = ""
        if value < 250 {
            returnString = String.init(format: "%02X", value)
        } else if value < 65536 {
            returnString = String.init(format:"%02X", 250) + intToLittleEndian(value: value)
        } else if value < 4294967296 {
            returnString = String.init(format: "%02X", 251) + String(longToLittleEndian(value: value).prefix(8))
        } else {
            returnString = String.init(format: "%02X", 252) + String(longToLittleEndian(value: value))
        }
        return returnString.uppercased()
    }
    
    static func intToLittleEndian(value: Int) -> String {
        let littleEndianBytes = withUnsafeBytes(of: value.littleEndian) { Data($0) }
        let valueLittleEndianString = BTCHexFromData(littleEndianBytes)
        return String(valueLittleEndianString!.prefix(4))
    }
    
    static func longToLittleEndian(value: Int) -> String {
        let littleEndianBytes = withUnsafeBytes(of: value.littleEndian) { Data($0) }
        let valueLittleEndianString = BTCHexFromData(littleEndianBytes)
        return valueLittleEndianString!
    }
}

extension String {
    func dataWithHexString() -> Data {
        var hex = self
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
}

