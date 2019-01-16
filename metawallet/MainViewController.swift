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
    
    var webView: WKWebView!
    
    let hostProvider = HostProvider.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let source = "var meta = document.createElement('meta');meta.name = 'viewport';meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';var head = document.getElementsByTagName('head')[0];head.appendChild(meta);";
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let config = WKWebViewConfiguration.init()
        config.userContentController.addUserScript(userScript)
        if #available(iOS 10, *) {
            config.ignoresViewportScaleLimits = false;
        }
        
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        let constraints = [webView.topAnchor.constraint(equalTo: view.topAnchor),
                           webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           webView.leftAnchor.constraint(equalTo: view.leftAnchor),
                           webView.rightAnchor.constraint(equalTo: view.rightAnchor)]
        NSLayoutConstraint.activate(constraints)
        
        webView.load(URLRequest(url: URL(string: HostProvider.Constants.webURL)!))
        addBridgeCommands()
        
        
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
                    self.webView.evaluateJavaScript("getWalletsDataResult('\(value)')", completionHandler: nil)
                }
            })
        }
    }
    
    func addWalletsHistoryRequest(to commander: BridgeCommander) {
        commander.add("getWalletsHistory") { (command) in
            APIClient.shared.getWalletsHistory(for: command.args, completion: { (error, errorCode, value) in
                if let value = value {
                    self.webView.evaluateJavaScript("getWalletsHistoryResult('\(value)')", completionHandler: nil)
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
        commander.add("sendTMHTx") { (command) in
            let args = command.args.split(separator: ",")
            guard args.count == 4 else {
                return
            }
            let fromAddress = String(args[0])
            let password = String(args[1])
            let toAddress = String(args[2])
            let amount = String(args[3])
            let fee = "0"
            let data = ""
            WalletService.createTransaction(address: fromAddress, password: password, to: toAddress, amount: amount, fee: fee, data: data, update: { (updateResult) in
                command.send(args: updateResult)
                self.webView.evaluateJavaScript("onTxChecked('\(updateResult)')", completionHandler: nil)
            }, completion: { (errorString, resultString) in
                command.send(args: errorString ?? "")
                self.webView.evaluateJavaScript("sendTMHTxResult('\(errorString ?? "")')", completionHandler: nil)
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
            let address = WalletService.importWallet(with: privayeKey, name: name, password: password, currencyId: currencyId, currencyName: currencyName)
            command.send(args: address)
            
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if (hostProvider.torrentBaseURL == nil || hostProvider.proxyBaseURL == nil) {
            hostProvider.configureIpAddresses(completion: { (success) in
                if Storage.shared.token != nil {
                    APIClient.shared.checkToken(completion: { (error, _) in
                        if error == nil {
                            self.webView.evaluateJavaScript("onConnectionReady(true)", completionHandler: nil)
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

extension MainViewController: QRCodeReaderViewControllerDelegate {
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        let privateKeyString = result.value
        let address = WalletService.importPrivateKeyWalletFromString(key: privateKeyString)
        reader.stopScanning()
        dismiss(animated: true, completion: nil)
        self.webView.evaluateJavaScript("saveImportedWallet('\(privateKeyString)', '\(address)')", completionHandler: nil)
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

