//
//  ViewController.swift
//  metawallet
//
//  Created by Maxim Mamedov on 01/10/2018.
//  Copyright © 2018 MAD. All rights reserved.
//

import UIKit
import WebKit
import AVFoundation
import QRCodeReader

class MainViewController: UIViewController, WKNavigationDelegate {
    
    lazy var readerVC: QRCodeReaderViewController = {
        let builder = QRCodeReaderViewControllerBuilder {
            $0.reader = QRCodeReader(metadataObjectTypes: [.qr], captureDevicePosition: .back)
        }
        
        return QRCodeReaderViewController(builder: builder)
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBOutlet weak var loadingView: UIView!
    var webView: FullScreenWKWebView!
    
    let hostProvider = HostProvider.shared

    var webKitLoaded = false
    
    var encryptedKeyString = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let source = "var meta = document.createElement('meta');meta.name = 'viewport';meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';var head = document.getElementsByTagName('head')[0];head.appendChild(meta);";
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        let config = WKWebViewConfiguration.init()
        config.suppressesIncrementalRendering = true
        config.userContentController.addUserScript(userScript)
        if #available(iOS 10, *) {
            config.ignoresViewportScaleLimits = false;
        }
        
        webView = FullScreenWKWebView(frame: CGRect.zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        view.insertSubview(webView, belowSubview: loadingView)
        let constraints = [webView.topAnchor.constraint(equalTo: view.topAnchor),
                           webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           webView.leftAnchor.constraint(equalTo: view.leftAnchor),
                           webView.rightAnchor.constraint(equalTo: view.rightAnchor)]
        NSLayoutConstraint.activate(constraints)
        
        webView.load(URLRequest(url: URL(string: HostProvider.Constants.webURL)!))
        addBridgeCommands()

        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func didBecomeActive() {
        guard let address = QRCodeHelper.shared.addressToOpen,
              let value = QRCodeHelper.shared.value else {
            return
        }
        if webKitLoaded {
            webView.load(URLRequest(url: URL(string: "\(HostProvider.Constants.webURL)#/create-transfer?to=\(address)&value=\(value)")!))
            QRCodeHelper.shared.addressToOpen = nil
            QRCodeHelper.shared.value = nil
        }
    }
    @IBAction func clean(_ sender: Any) {
        WebCacheCleaner.clean()
        self.webView.load(URLRequest(url: URL(string: HostProvider.Constants.webURL)!))
    }
    
    func addBridgeCommands() {
        let commander = BridgeCommander(webView)
        
        addGetAppVersionRequest(to: commander)
        
        addSignUpRequest(to: commander)
        
        addSignInRequest(to: commander)
        
        addWalletsDataReuqest(to: commander)
        
        addWalletsHistoryRequest(to: commander)
        
        addCreateAddressRequest(to: commander)
        
        addCreateTransactionRequest(to: commander)
        
        addClearCacheRequest(to: commander)
        
        addQRImportRequest(to: commander)
        
        addImportWalletRequest(to: commander)
        
        addQRExportRequest(to: commander)
        
        addOnlyLocalAddressesRequest(to: commander)
        
        addLogOutRequest(to: commander)
        
        addGetOnlyLocalAddressesRequest(to: commander)
        
        addGetAuthDataRequest(to: commander)
        
        addEncryptedWalletRequest(to: commander)
        
        addQRDecryptedExportRequest(to: commander)
    }
    
    func addGetAuthDataRequest(to commander: BridgeCommander) {
        commander.add("getAuthData") { (command) in
            command.send(args: Storage.shared.login ?? "")
        }
    }
    
    func addLogOutRequest(to commander: BridgeCommander) {
        commander.add("logOut") { (command) in
            Storage.shared.token = nil
            Storage.shared.refreshToken = nil
            Storage.shared.onlyLocalAddresses = false
            Storage.shared.login = nil
        }
    }
    
    func addGetOnlyLocalAddressesRequest(to commander: BridgeCommander) {
        commander.add("getOnlyLocalAddresses") { (command) in
            let onlyLocal = Storage.shared.onlyLocalAddresses
            command.send(args: "\(onlyLocal ? "true" : "false")")
        }
    }
    
    func addOnlyLocalAddressesRequest(to commander: BridgeCommander) {
        commander.add("setOnlyLocalAddresses") { (command) in
            var args = command.args
            if args.isEmpty {
                args = "0"
            }
            let onlyLocal = Bool(exactly: Int(args)! as NSNumber)!
            Storage.shared.onlyLocalAddresses = onlyLocal
        }
    }
    
    func addQRExportRequest(to commander: BridgeCommander) {
        commander.add("getPrivateKey") { (command) in
            let args = command.args.split(separator: ",")
            command.send(args: WalletService.getPrivateKeyString(address: String(args[0]), password: String(args[1])))
        }
    }
    
    func addQRDecryptedExportRequest(to commander: BridgeCommander) {
        commander.add("getPrivateKeyDecrypted") { (command) in
            let args = command.args.split(separator: ",")
            var status = "OK"
            let key = WalletService.getDecryptedPrivateKeyString(address: String(args[0]), password: String(args[2]))
            if key == "NO_PRIVATE_KEY_FOUND" || key == "WRONG_PASSWORD" {
                status = key
            }
            let data = ["key" : key,
                        "status" : status]
            try? command.send(args: String(data: JSONSerialization.data(withJSONObject: data, options: .sortedKeys), encoding: .utf8) ?? "")
        }
    }
    
    func addQRImportRequest(to commander: BridgeCommander) {
        commander.add("startQRImport") { (command) in
            // Retrieve the QRCode content
            // By using the delegate pattern
            self.readerVC.delegate = self
            
            // Presents the readerVC as modal form sheet
            self.readerVC.modalPresentationStyle = .formSheet
            self.present(self.readerVC, animated: true, completion: nil)
        }
    }
    
    func addClearCacheRequest(to commander: BridgeCommander) {
        commander.add("clearCache") { (command) in
            WebCacheCleaner.clean()
            self.webView.load(URLRequest(url: URL(string: HostProvider.Constants.webURL)!))
        }
    }
    
    func addGetAppVersionRequest(to commander: BridgeCommander) {
        commander.add("getAppVersion") { (command) in
            let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            command.send(args: versionNumber)
        }
    }
    
    func addSignUpRequest(to commander: BridgeCommander) {
        commander.add("signUp") { (command) in
            Storage.shared.onlyLocalAddresses = false
            let substrings = command.args.split(separator: ",")
            guard substrings.count == 2 else {
                self.webView.evaluateJavaScript("signUpResult('400','Bad request')", completionHandler: nil)
                return
            }
            
            APIClient.shared.register(with: String(substrings.first!), password: String(substrings.last!), completion: { (error, code) in
                let errorMessage = error?.localizedDescription ?? ""
                let errorCode = code == nil ? "" : String(code!)
                self.webView.evaluateJavaScript("signUpResult('\(errorCode)','\(errorMessage)')", completionHandler: nil)
            })
        }
    }
    
    func addSignInRequest(to commander: BridgeCommander) {
        commander.add("getAuthRequest") { (command) in
            Storage.shared.onlyLocalAddresses = false
            let substrings = command.args.split(separator: ",")
            guard substrings.count == 2 else {
                self.webView.evaluateJavaScript("getAuthRequestResult('400','Bad request')", completionHandler: nil)
                return
            }
            
            APIClient.shared.auth(with: String(substrings.first!), password: String(substrings.last!), completion: { (error, code) in
                let errorMessage = error?.localizedDescription ?? ""
                let errorCode = code == nil ? "" : String(code!)
                self.webView.evaluateJavaScript("getAuthRequestResult('\(errorCode)','\(errorMessage)')", completionHandler: nil)
            })
        }
    }
    
    func addWalletsDataReuqest(to commander: BridgeCommander) {
        commander.add("getWalletsData") { (command) in
            APIClient.shared.getWallets(for: command.args, completion: { (error, errorCode, value) in
                if let value = value {
                    command.send(args: value)
                }
            })
        }
    }
    
    func addWalletsHistoryRequest(to commander: BridgeCommander) {
        commander.add("getWalletsHistory") { (command) in
            APIClient.shared.getWalletsHistory(for: command.args, completion: { (error, errorCode, value) in
                if let value = value {
                    command.send(args: value)
                }
            })
        }
    }
    
    func addCreateAddressRequest(to commander: BridgeCommander) {
        commander.add("createAddress") { (command) in
            let args = command.args.split(separator: ",")
            guard args.count == 4 else {
                return
            }
            let name = String(args[0])
            let password = String(args[1])
            let abbreviation = String(args[2])
            let currencyId = String(args[3])
            let wallet = WalletService.generateNewWallet(currencyId: currencyId, currencyCode: abbreviation, password: password, name: name)!
            APIClient.shared.syncWallet(wallet: wallet, completion: { (_, _) in
                command.send(args: "\(wallet.address)")
            })
        }
    }
    
    func addCreateTransactionRequest(to commander: BridgeCommander) {
        commander.add("sendTx") { (command) in
            let args = command.args.split(separator: ",")
            guard args.count == 5 else {
                return
            }
            let fromAddress = String(args[0])
            let password = String(args[1])
            let toAddress = String(args[2])
            let amount = String(args[3])
            let currency = String(args.last!)
            let fee = "0"
            let data = ""
            WalletService.createTransaction(address: fromAddress, password: password, to: toAddress, amount: amount, fee: fee, data: data, currency: currency, initialized: { (updateResult) in
//                command.send(args: updateResult)
                command.send(args: updateResult)
            }, check: { (updateResult) in
                print("onTxChecked('\(updateResult)')")
                self.webView.evaluateJavaScript("onTxChecked('\(updateResult)')", completionHandler: nil)
            }, completion: { _ in
                APIClient.shared.updateWallets(for: currency, completion: { (error, errorCode, value) in
                    self.webView.evaluateJavaScript("window.onDataRefreshed();", completionHandler: nil)
                })
            }, error: { errorString in
                command.error(args: errorString)
            })
        }
    }
    
    func addImportWalletRequest(to commander: BridgeCommander) {
        commander.add("importWallet") { (command) in
            let args = command.args.split(separator: ",")
            guard args.count == 6 else {
                return
            }
            let privayeKey = String(args[1])
            let name = String(args[2])
            let password = String(args[3])
            let currencyId = String(args[4])
            let currencyName = String(args[5])
            WalletService.importWallet(with: privayeKey, name: name, password: password, currencyId: currencyId, currencyName: currencyName, completion: { address in
                command.send(args: address)
            })
            
        }
    }
    
    func addEncryptedWalletRequest(to commander: BridgeCommander) {
        commander.add("importPrivateWallet") { (command) in
            let args = command.args.split(separator: ",")
            guard args.count == 4 else {
                return
            }
            let password = String(args[0])
            let currencyId = String(args[1])
            if currencyId != "1" && currencyId != "4" {
                command.send(args: "{\"status\" : \"INCORRECT_CURRENCY\", \"address\" : \"\"}")
                return
            }
            let currencyName = String(args[2])
            let name = String(args[3])
            WalletService.importWallet(with: self.encryptedKeyString, name: name, password: password, currencyId: currencyId, currencyName: currencyName, completion: { (address) in
                if address.contains("INCORRECT_KEY") {
                    command.send(args: "{\"status\" : \"INCORRECT_KEY\", \"address\" : \"\"}")
                    return
                }
                if address.contains("Error") {
                    command.send(args: "{\"status\" : \"INCORRECT_PASSWORD\", \"address\" : \"\"}")
                    return
                }
                command.send(args: "{\"status\" : \"OK\", \"address\" : \"\(address)\"}")
            })
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Finished")
        loadingView.isHidden = true
        if (hostProvider.mainTorrentBaseURL == nil || hostProvider.mainProxyBaseURL == nil) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(2)) {
                self.webKitLoaded = true
                self.hostProvider.configureIpAddresses(completion: { (success) in
                    if Storage.shared.token != nil {
                        APIClient.shared.checkToken(completion: { (error, _) in
                            if error == nil {
                                self.webView.evaluateJavaScript("onConnectionReady(true)", completionHandler: nil)
                                self.didBecomeActive()
                            } else {
                                self.webView.evaluateJavaScript("onConnectionReady(false)", completionHandler: nil)
                            }
                        })
                    } else {
                        self.webView.evaluateJavaScript("onConnectionReady(false)", completionHandler: nil)
                    }
                }) { (progressDict) in
                    let jsonData = try! JSONSerialization.data(withJSONObject: progressDict, options: JSONSerialization.WritingOptions.sortedKeys)
                    let jsonString = String.init(data: jsonData, encoding: .utf8)!
                    self.webView.evaluateJavaScript("updateConnectingStatus('\(jsonString)')", completionHandler: { (_, _) in
                    })
                }
            }
        }
    }

}

extension MainViewController: QRCodeReaderViewControllerDelegate {
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        let privateKeyString = result.value
        
        reader.stopScanning()
        dismiss(animated: true, completion: nil)
        
        if privateKeyString.starts(with: "307702") {
            self.webView.evaluateJavaScript("saveImportedWallet('', '', 'QR_UNSUPPORTED')", completionHandler: nil)
            return
        }
        if privateKeyString.contains("BEGIN EC PRIVATE KEY") {
            encryptedKeyString = privateKeyString
            self.webView.evaluateJavaScript("saveImportedWallet('', '', 'QR_ENCRYPTED')", completionHandler: nil)
            return
        }
        let address = WalletService.importPrivateKeyWalletFromString(key: privateKeyString)
        if address == "Error" {
            self.webView.evaluateJavaScript("saveImportedWallet('', '', 'QR_INVALID')", completionHandler: nil)
            return
        }
        self.webView.evaluateJavaScript("saveImportedWallet('\(privateKeyString)', '\(address)', '')", completionHandler: nil)
    }
    
    //This is an optional delegate method, that allows you to be notified when the user switches the cameraName
    //By pressing on the switch camera button
    func reader(_ reader: QRCodeReaderViewController, didSwitchCamera newCaptureDevice: AVCaptureDeviceInput) {
        print("Switching capture to: \(newCaptureDevice.device.localizedName)")
    }
    
    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.stopScanning()
        dismiss(animated: true, completion: nil)
    }
}

