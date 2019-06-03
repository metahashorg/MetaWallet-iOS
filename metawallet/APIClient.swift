//
//  APIClient.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 18/12/2018.
//  Copyright © 2018 MAD. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

extension DataResponse {
    func getStatusCode() -> Int? {
        if response?.statusCode != nil {
            return response?.statusCode
        }
        guard let nsError = error as NSError? else {
            return nil
        }
        return nsError.code
    }
}

class RequestsRetrier: RequestRetrier {
    
    public func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: RequestRetryCompletion) {
        completion(request.retryCount <= 5, 1.0) // retry after 1 second
        // Or do something with the retryCount
        // i.e. completion(request.retryCount <= 10, 1.0)
    }
}

class APIClient {
    static let shared = APIClient()
    
    var refreshTimer: Timer?
    
    init(){
        sessionManager.retrier = RequestsRetrier()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true, block: { (_) in
            self.updateWallets(for: "1", completion: { (_, _, _) in })
            self.updateWallets(for: "4", completion: { (_, _, _) in })
        })
    }
    
    let sessionManager = SessionManager()
    
    let deviceIdentifier = UIDevice.current.identifierForVendor!.uuidString
    
        
    func register(with login: String, password: String, completion: @escaping (Error?, Int?) -> Void) {
        let params = ["id" : deviceIdentifier,
                      "version": "1.0.0",
                      "method" : "user.register",
                      "token" : "",
                      "params" : [["login" : login, "password" : password]]
            ] as [String : Any]
        Alamofire.request(HostProvider.Constants.baseURL, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            if response.error == nil {
                self.auth(with: login, password: password, completion: completion)
            } else {
                completion(response.error, response.error != nil ? response.getStatusCode() : nil)
            }
        }
    }
    
    func auth(with login: String, password: String, completion: @escaping (Error?, Int?) -> Void) {
        let params = ["id" : deviceIdentifier,
                      "version": "1.0.0",
                      "method" : "user.auth",
                      "token" : "",
                      "params" : [["login" : login, "password" : password]]
            ] as [String : Any]
        Alamofire.request(HostProvider.Constants.baseURL, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                let token = json["data"]["token"].string
                let refreshToken = json["data"]["refresh_token"].string
                Storage.shared.token = token
                Storage.shared.refreshToken = refreshToken
                Storage.shared.login = login
            }
            completion(response.error, response.error != nil ? response.getStatusCode() : nil)
        }
    }
    
    func checkToken(completion: @escaping (Error?, Int?) -> Void) {
        let params = ["id" : deviceIdentifier,
                      "version": "1.0.0",
                      "method" : "user.token.refresh",
                      "token" : Storage.shared.refreshToken ?? "",
                      "params" : []
            ] as [String : Any]
        Alamofire.request(HostProvider.Constants.baseURL, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                let token = json["data"]["access"].string
                let refreshToken = json["data"]["refresh"].string
                Storage.shared.token = token
                Storage.shared.refreshToken = refreshToken
            } else {
                Storage.shared.token = nil
                Storage.shared.refreshToken = nil
            }
            completion(response.error, response.error != nil ? response.getStatusCode() : nil)
        }
    }
    
    func syncWallet(wallet: Wallet, completion: @escaping (Error?, Int?) -> Void) {
        let params = ["id" : deviceIdentifier,
                      "version": "1.0.0",
                      "method" : "address.create",
                      "token" : Storage.shared.token ?? "",
                      "params" : [["currency" : Int(wallet.currency)!, "address" : wallet.address, "pubkey" : wallet.publicKey, "password" : wallet.password]]
            ] as [String : Any]
        Alamofire.request(HostProvider.Constants.baseURLWallet, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            completion(response.error, response.error != nil ? response.getStatusCode() : nil)
        }
    }
    
    func updateWallets(for currency: String, completion: @escaping (Error?, Int?, String?) -> Void) {
        let onlyLocal = Storage.shared.onlyLocalAddresses
        let savedWallets = Storage.shared.getWallets(for: currency)
        var descriptions = [[String : Any]]()

        let params = ["id" : deviceIdentifier,
                      "version": "1.0.0",
                      "method" : "address.list",
                      "token" : Storage.shared.token ?? "",
                      "params" : [["currency" : Int(currency)!]]
            ] as [String : Any]
        Alamofire.request(HostProvider.Constants.baseURLWallet, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                var wallets = [Wallet]()
                for wallet in json["data"].arrayValue {
                    let wallet = Wallet(name:wallet["name"].stringValue, currency: wallet["currency"].stringValue, publicKey: wallet["public_key"].stringValue, currencyCode: wallet["currency_code"].stringValue, address: wallet["address"].stringValue, password: wallet["password"].stringValue)
                    wallets.append(wallet)
                }
                mergeWallets(remoteWallets: &wallets, localWallets: savedWallets)
                var walletsCount = 0
                print("wallets count = \(wallets.count)")
                if wallets.count == 0 {
                    let jsonString = try! String(data: JSONSerialization.data(withJSONObject: descriptions, options: .sortedKeys), encoding: .utf8)
                    completion(nil, nil, jsonString)
                    return
                }
                for i in 0..<wallets.count {
                    print("loading i = \(i)")
                    wallets[i].updateBalance(completion: { (newBalance, _) in
                        print("loaded i = \(i)")
                        wallets[i].balance = newBalance
                        walletsCount += 1
                        if walletsCount == wallets.count {
                            Storage.shared.setWallets(wallets, for: currency)
                            for wallet in wallets {
                                if onlyLocal && !wallet.hasPrivateKey {
                                    continue
                                }
                                descriptions.append(wallet.getDescription())
                            }
                            let jsonString = try! String(data: JSONSerialization.data(withJSONObject: descriptions, options: .sortedKeys), encoding: .utf8)
                            completion(nil, nil, jsonString)
                        }
                    })
                }
            }
        }
    }
    
    func getWallets(for currency: String, completion: @escaping (Error?, Int?, String?) -> Void) {
        var descriptions = [[String : Any]]()
        let onlyLocal = Storage.shared.onlyLocalAddresses
        let savedWallets = Storage.shared.getWallets(for: currency)
        if savedWallets.count > 0 {
            for wallet in savedWallets {
                if onlyLocal && !wallet.hasPrivateKey {
                    continue
                }
                descriptions.append(wallet.getDescription())
            }
            let jsonString = try! String(data: JSONSerialization.data(withJSONObject: descriptions, options: .sortedKeys), encoding: .utf8)
            completion(nil, nil, jsonString)
        } else {
            updateWallets(for: currency, completion: completion)
        }
    }
    
    func getWalletsHistory(for currency: String, completion: @escaping (Error?, Int?, String?) -> Void) {
        let wallets = Storage.shared.getWallets(for: currency)
        
        var transactions = [[String : Any]]()
        
        var walletsCount = 0
        
        var torrentURL = HostProvider.shared.devTorrentBaseURL
        if currency == "4" {
            torrentURL = HostProvider.shared.mainTorrentBaseURL
        }
        
        guard let url = torrentURL else {
            return
        }
        
        for i in 0..<wallets.count {
            let params = ["id" : deviceIdentifier,
                          "version": "1.0.0",
                          "method" : "fetch-history",
                          "token" : "",
                          "params" : ["address" : wallets[i].address]
                ] as [String : Any]
            Alamofire.request(url, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
                walletsCount += 1
                if response.error == nil, let value = response.value {
                    let json = JSON(value)
                    for transaction in json["result"].arrayValue {
                        let dict = ["from" : transaction["from"].stringValue,
                                    "timestamp" : transaction["timestamp"].intValue,
                                    "value" : transaction["value"].intValue,
                                    "to" : transaction["to"].stringValue,
                                    "currency" : currency,
                                    "transaction" : transaction["transaction"].stringValue
                                    ] as [String : Any]
                        transactions.append(dict)
                    }
                }
                if walletsCount == wallets.count {
                    let string = try! String.init(data: JSONSerialization.data(withJSONObject: transactions, options: .sortedKeys), encoding: .utf8)
                    completion(nil, nil, string)
                }
            }
        }
    }
    
    func getWalletBalance(for address: String, currency: String, completion: @escaping (Double, Int) -> Void) {
        let params = ["id" : deviceIdentifier,
                      "version": "1.0.0",
                      "method" : "fetch-balance",
                      "token" : "",
                      "params" : ["address" : address]
            ] as [String : Any]
        
        var torrentURL = HostProvider.shared.devTorrentBaseURL
        if currency == "4" {
            torrentURL = HostProvider.shared.mainTorrentBaseURL
        }
        
        guard let url = torrentURL else {
            return
        }
        
        Alamofire.request(url, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                let received = json["result"]["received"].doubleValue
                let spent = json["result"]["spent"].doubleValue
                let countSpent = json["result"]["count_spent"].intValue
                completion(received - spent, countSpent)
            } else {
                completion(0, 0)
            }
        }
    }
    
    func sendTransaction(transaction: Transaction, updateStatus: @escaping () -> Void, completion: @escaping () -> Void) {
        let params = ["jsonrpc" : "2.0",
                      "method": "mhc_send",
                      "params" : [
                        "to" : transaction.to,
                        "value" : transaction.value,
                        "fee" : transaction.fee,
                        "nonce" : transaction.nonce,
                        "data" : transaction.data,
                        "pubkey" : transaction.pubKey,
                        "sign" : transaction.sign
            ]
            ] as [String : Any]
        var firstProxy = "http://\(HostProvider.shared.devProxyIPs.first!):\(HostProvider.Constants.proxyPort)"
        var secondProxy = "http://\(HostProvider.shared.devProxyIPs[1]):\(HostProvider.Constants.proxyPort)"
        var thirdProxy = "http://\(HostProvider.shared.devProxyIPs[2]):\(HostProvider.Constants.proxyPort)"
        if transaction.currency == "4" {
            firstProxy = "http://\(HostProvider.shared.mainProxyIPs.first!):\(HostProvider.Constants.proxyPort)"
            secondProxy = "http://\(HostProvider.shared.mainProxyIPs[1]):\(HostProvider.Constants.proxyPort)"
            thirdProxy = "http://\(HostProvider.shared.mainProxyIPs[2]):\(HostProvider.Constants.proxyPort)"
        }
        
        var completedRequests = 0
        sessionManager.request(firstProxy, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            var proxyArray = WalletService.shared.txInfo["proxy"] as! [Any]
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                let id = json["params"].stringValue
                WalletService.shared.txInfo["id"] = id
                proxyArray[0] = "ok"
            } else {
                proxyArray[0] = "error"
            }
            WalletService.shared.txInfo["proxy"] = proxyArray
            WalletService.shared.txInfo["stage"] = 2
            updateStatus()
            completedRequests += 1
            if completedRequests == 3 {
                completion()
            }
        }
        sessionManager.request(secondProxy, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            var proxyArray = WalletService.shared.txInfo["proxy"] as! [Any]
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                let id = json["params"].stringValue
                WalletService.shared.txInfo["id"] = id
                proxyArray[1] = "ok"
            } else {
                proxyArray[1] = "error"
            }
            WalletService.shared.txInfo["proxy"] = proxyArray
            WalletService.shared.txInfo["stage"] = 2
            updateStatus()
            completedRequests += 1
            if completedRequests == 3 {
                completion()
            }
        }
        sessionManager.request(thirdProxy, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            var proxyArray = WalletService.shared.txInfo["proxy"] as! [Any]
            if response.error == nil, let value = response.value {
                let json = JSON(value)
                let id = json["params"].stringValue
                WalletService.shared.txInfo["id"] = id
                proxyArray[2] = "ok"
            } else {
                proxyArray[2] = "error"
            }
            WalletService.shared.txInfo["proxy"] = proxyArray
            WalletService.shared.txInfo["stage"] = 2
            updateStatus()
            completedRequests += 1
            if completedRequests == 3 {
                completion()
            }
        }
    }
    
    func checkTransaction(transactionHash: String, currency: String, updateStatus: @escaping () -> Void, completion: @escaping () -> Void) {
        let params = ["uid" : deviceIdentifier,
                        "method":"get-tx",
                        "params":["hash":transactionHash],
                        "token":"",
                        "version":"1.0.0"
        ] as [String : Any]
        var firstTorrent = "http://\(HostProvider.shared.devTorrentIPs.first!):\(HostProvider.Constants.torrentPort)"
        var secondTorrent = "http://\(HostProvider.shared.devTorrentIPs[1]):\(HostProvider.Constants.torrentPort)"
        var thirdTorrent = "http://\(HostProvider.shared.devTorrentIPs[2]):\(HostProvider.Constants.torrentPort)"
        
        if currency == "4" {
            firstTorrent = "http://\(HostProvider.shared.mainTorrentIPs.first!):\(HostProvider.Constants.torrentPort)"
            secondTorrent = "http://\(HostProvider.shared.mainTorrentIPs[1]):\(HostProvider.Constants.torrentPort)"
            thirdTorrent = "http://\(HostProvider.shared.mainTorrentIPs[2]):\(HostProvider.Constants.torrentPort)"
        }
        var completedRequests = 0
        sessionManager.request(firstTorrent, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            var torrentArray = WalletService.shared.txInfo["torrent"] as! [Any]
            if response.error == nil, let _ = response.value {
                torrentArray[0] = "ok"
            } else {
                torrentArray[0] = "error"
            }
            WalletService.shared.txInfo["torrent"] = torrentArray
            WalletService.shared.txInfo["stage"] = 3
            updateStatus()
            completedRequests += 1
            if completedRequests == 3 {
                completion()
                WalletService.shared.resetTxInfo()
            }
        }
        sessionManager.request(secondTorrent, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            var torrentArray = WalletService.shared.txInfo["torrent"] as! [Any]
            if response.error == nil, let _ = response.value {
                torrentArray[1] = "ok"
            } else {
                torrentArray[1] = "error"
            }
            WalletService.shared.txInfo["torrent"] = torrentArray
            WalletService.shared.txInfo["stage"] = 3
            updateStatus()
            completedRequests += 1
            if completedRequests == 3 {
                completion()
                WalletService.shared.resetTxInfo()
            }
        }
        sessionManager.request(thirdTorrent, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate().responseJSON { (response) in
            var torrentArray = WalletService.shared.txInfo["torrent"] as! [Any]
            if response.error == nil, let _ = response.value {
                torrentArray[2] = "ok"
            } else {
                torrentArray[2] = "error"
            }
            WalletService.shared.txInfo["torrent"] = torrentArray
            WalletService.shared.txInfo["stage"] = 3
            updateStatus()
            completedRequests += 1
            if completedRequests == 3 {
                completion()
                WalletService.shared.resetTxInfo()
            }
        }
    }
}
