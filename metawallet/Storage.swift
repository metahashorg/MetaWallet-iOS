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
    
    var iCloudDocumentsURL: URL?
    
    init() {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            self.iCloudDocumentsURL = iCloudDocumentsURL
            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                do {
                    try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                }
                catch {
                    //Error handling
                    print("Error in creating doc")
                }
            }
        }
    }
    
    func saveToiCloudDrive(wallet: Wallet) {
        guard let iCloud = iCloudDocumentsURL,
            let key = wallet.btcKey,
            let pemData = KeyFormatter.encrypt(key, password: wallet.password) else {
            return
        }
        let fullURL = iCloud.appendingPathComponent("\(wallet.address)").appendingPathExtension("ec").appendingPathExtension("priv")
        try? pemData.write(to: fullURL)
    }
    
    var devTorrentBaseURLStrings: [String]? {
        get {
            let wrapper = UserDefaults.standard
            if let lastDate = wrapper.object(forKey: "devTorrentBaseURLStringsDate") as? Date {
                if abs(lastDate.timeIntervalSinceNow) < 86400 * 5 {
                    return wrapper.object(forKey: "devTorrentBaseURLStrings") as? [String]
                } else {
                    return nil
                }
            }
            return nil
        } set {
            let wrapper = UserDefaults.standard
            wrapper.set(newValue!, forKey: "devTorrentBaseURLStrings")
            wrapper.setValue(Date(), forKey: "devTorrentBaseURLStringsDate")
        }
    }

    var devProxyBaseURLStrings: [String]? {
        get {
            let wrapper = UserDefaults.standard
            if let lastDate = wrapper.object(forKey: "devProxyBaseURLStringsDate") as? Date {
                if abs(lastDate.timeIntervalSinceNow) < 86400 * 5 {
                    return wrapper.object(forKey: "devProxyBaseURLStrings") as? [String]
                } else {
                    return nil
                }
            }
            return nil
        } set {
            let wrapper = UserDefaults.standard
            wrapper.set(newValue!, forKey: "devProxyBaseURLStrings")
            wrapper.setValue(Date(), forKey: "devProxyBaseURLStringsDate")
        }
    }

    var mainTorrentBaseURLStrings: [String]? {
        get {
            let wrapper = UserDefaults.standard
            if let lastDate = wrapper.object(forKey: "mainTorrentBaseURLStringsDate") as? Date {
                if abs(lastDate.timeIntervalSinceNow) < 86400 * 5 {
                    return wrapper.object(forKey: "mainTorrentBaseURLStrings") as? [String]
                } else {
                    return nil
                }
            }
            return nil
        } set {
            let wrapper = UserDefaults.standard
            wrapper.set(newValue!, forKey: "mainTorrentBaseURLStrings")
            wrapper.setValue(Date(), forKey: "mainTorrentBaseURLStringsDate")
        }
    }

    var mainProxyBaseURLStrings: [String]? {
        get {
            let wrapper = UserDefaults.standard
            if let lastDate = wrapper.object(forKey: "mainProxyBaseURLStringsDate") as? Date {
                if abs(lastDate.timeIntervalSinceNow) < 86400 * 5 {
                    return wrapper.object(forKey: "mainProxyBaseURLStrings") as? [String]
                } else {
                    return nil
                }
            }
            return nil
        } set {
            let wrapper = UserDefaults.standard
            wrapper.set(newValue!, forKey: "mainProxyBaseURLStrings")
            wrapper.setValue(Date(), forKey: "mainProxyBaseURLStringsDate")
        }
    }
    
    var lan: String {
        get {
            let wrapper = KeychainWrapper.standard
            return wrapper.string(forKey: #function) ?? ""
        } set {
            let wrapper = KeychainWrapper.standard
            wrapper.set(newValue, forKey: #function)
        }
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
    
    var login: String? {
        get {
            let wrapper = KeychainWrapper.standard
            return wrapper.string(forKey: "login")
        } set {
            let wrapper = KeychainWrapper.standard
            if newValue == nil {
                wrapper.removeObject(forKey: "login")
                return
            }
            wrapper.set(newValue!, forKey: "login")
        }
    }
    
    var onlyLocalAddresses: Bool {
        get {
            let wrapper = KeychainWrapper.standard
            return wrapper.bool(forKey: "onlyLocalAddresses") ?? false
        } set {
            let wrapper = KeychainWrapper.standard
            wrapper.set(newValue, forKey: "onlyLocalAddresses")
        }
    }
    
    func getWallets(for currency: String) -> [Wallet] {
        guard let login = login else {
            return []
        }
        let wrapper = KeychainWrapper.standard
        if let savedWallets = wrapper.data(forKey: "wallets_\(login.lowercased())_\(currency)") {
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
    
    func getWallets() -> [Wallet] {
        var allWallets: [Wallet] = []
        for i in 0..<5 {
            allWallets.append(contentsOf: getWallets(for: "\(i)"))
        }
        return allWallets
    }
    
    func setWallets(_ wallets: [Wallet], for currency: String) {
        if wallets.isEmpty {
            return
        }
        guard let login = login else {
            return
        }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(wallets) {
            let wrapper = KeychainWrapper.standard
            wrapper.set(encoded, forKey: "wallets_\(login.lowercased())_\(currency)")
        }
    }
    
}
