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

    static func generateNewWallet(currencyId: String, currencyCode: String, password: String, name: String) -> Wallet? {
        guard let btcKey = BTCKey.init() else {
            return nil
        }
        let wallet = Wallet.init(name: name, currency: currencyId, currencyCode: currencyCode, password: password, privateKeyData: btcKey.privateKey as Data, publicKeyData: btcKey.publicKey as Data)
        var wallets = Storage.shared.wallets
        wallets.append(wallet)
        Storage.shared.wallets = wallets
        return wallet
    }
    
    static func createTransaction(address: String, password: String, to: String, amount: String, fee: String, data: String, update: @escaping (String) -> Void, completion: (String?, String?) -> Void) {
        guard let wallet = Storage.shared.wallets.first(where: { (wallet) -> Bool in
            return wallet.address == address && wallet.privateKeyData != nil
        }) else {
            completion("NO_PRIVATE_KEY_FOUND", nil)
            return
        }
        if wallet.password != password && wallet.password != "" {
            completion("WRONG_PASSWORD", nil)
            return
        }
        shared.txInfo = ["id":"",
                  "proxy":["wait","wait","wait"],
                  "stage":1,
                  "torrent":["wait","wait","wait"]
        ]
        wallet.updateBalance { (balance, spent) in
            let nonce = Int(spent + 1)
            let dataHexString = BTCHexFromData(data.data(using: .utf8)!)!
            let signatureMessage = generateSignatureMessage(to: to, value: amount, nonce: String(nonce), fee: fee, data: data).lowercased()
            let messageData = signatureMessage.dataWithHexString()
            let signature = Hashing.sign(messageData, with: wallet.btcKey!)!
            let signatureString = BTCHexFromData(signature)!
            let publicKeyHex = publicKeyHexString(from: wallet.publicKeyData!).lowercased()
            
            let transaction = Transaction.init(to: to, value: amount, fee: fee, nonce: String(nonce), data: dataHexString, pubKey: publicKeyHex, sign: signatureString)
            
            let initUpdate = try! String.init(data: JSONSerialization.data(withJSONObject: shared.txInfo, options: .sortedKeys), encoding: .utf8)!
            update(initUpdate)
            
            APIClient.shared.sendTransaction(transaction: transaction, updateStatus: {
                let updateString = try! String.init(data: JSONSerialization.data(withJSONObject: shared.txInfo, options: .sortedKeys), encoding: .utf8)!
                update(updateString)
            }, completion: {
                APIClient.shared.checkTransaction(transactionHash: shared.txInfo["id"] as! String, updateStatus: {
                    let updateString = try! String.init(data: JSONSerialization.data(withJSONObject: shared.txInfo, options: .sortedKeys), encoding: .utf8)!
                    update(updateString)
                }, completion: {
                    
                })
            })
        }
    }
    
    static func importPrivateKeyWalletFromString(key: String) -> String {
        guard let key = KeyFormatter.createKey(fromDERString: key) else {
            return "Error"
        }
        let address = addressHexString(from: key.publicKey as Data)
        return address
    }
    
    
    static func importWallet(with privateKey: String, name: String, password: String, currencyId: String, currencyName: String) -> String {
        guard let key = KeyFormatter.createKey(fromDERString: privateKey) else {
            return "Error"
        }
        let address = addressHexString(from: key.publicKey as Data)
        var wallets = Storage.shared.wallets
        if let loadedWalletIndex = wallets.firstIndex(where: { (wallet) -> Bool in
            return wallet.address == address
        }) {
            wallets[loadedWalletIndex].privateKeyData = key.privateKey! as Data
            wallets[loadedWalletIndex].publicKeyData = key.publicKey! as Data
            Storage.shared.wallets = wallets
            return address
        } else {
            let wallet = Wallet.init(name: name, currency: currencyId, currencyCode: currencyName, password: password, privateKeyData: key.privateKey as Data, publicKeyData: key.publicKey as Data)
            var wallets = Storage.shared.wallets
            wallets.append(wallet)
            Storage.shared.wallets = wallets
            APIClient.shared.syncWallet(wallet: wallet, completion: { (_, _) in
            })
            return address
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

