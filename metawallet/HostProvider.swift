//
//  HostProvider.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 11/12/2018.
//  Copyright © 2018 MAD. All rights reserved.
//

import Foundation

class HostProvider {
    
    struct Constants {
        static let webURL = "https://mgapp.metahash.io/"
        
        //prod for decenter ip resolving
        static let urlProxyURL = "proxy.net-main.metahashnetwork.com"
        static let urlTorrentURL = "tor.net-main.metahashnetwork.com"
        
        //dev for decenter ip resolving
        static let urlProxyDevURL = "proxy.net-dev.metahashnetwork.com"
        static let urlTorrentDevURL = "tor.net-dev.metahashnetwork.com"
        
        //for login
        static let baseURL = "https://id.metahash.org/api/"
        static let baseURLDev = "http://id-dev.metahash.local/api/"
        
        //for wallet operations
        static let baseURLWallet = "https://wallet.metahash.org/api/"
                
        static let torrentPort = "5795"
        static let proxyPort = "9999"
    }
    
    let pinger = Pinger()
    
    var devTorrentBaseURL: URL?
    var devProxyBaseURL: URL?
    
    var devTorrentIPs = [String]()
    var devProxyIPs = [String]()
    
    var mainTorrentBaseURL: URL?
    var mainProxyBaseURL: URL?
    
    var mainTorrentIPs = [String]()
    var mainProxyIPs = [String]()
    
    static let shared = HostProvider()

    func configureIpAddresses(completion: @escaping (Bool) -> Void, progress: @escaping (([String : Any]) -> Void)) {
//        if let cachedDevTorrentBaseURLStrings = Storage.shared.devTorrentBaseURLStrings,
//            cachedDevTorrentBaseURLStrings.count > 0,
//            let cachedDevProxyBaseURLStrings = Storage.shared.devProxyBaseURLStrings,
//            cachedDevProxyBaseURLStrings.count > 0,
//            let cachedMainTorrentBaseURLStrings = Storage.shared.mainTorrentBaseURLStrings,
//            cachedMainTorrentBaseURLStrings.count > 0,
//            let cachedMainProxyBaseURLStrings = Storage.shared.mainProxyBaseURLStrings,
//            cachedMainProxyBaseURLStrings.count > 0 {
//            devTorrentBaseURL = URL(string: "http://".appending(cachedDevTorrentBaseURLStrings.randomElement()!).appending(":").appending(HostProvider.Constants.torrentPort))
//            devProxyBaseURL = URL(string: "http://".appending(cachedDevProxyBaseURLStrings.randomElement()!).appending(":").appending(HostProvider.Constants.proxyPort))
//            mainTorrentBaseURL = URL(string: "http://".appending(cachedMainTorrentBaseURLStrings.randomElement()!).appending(":").appending(HostProvider.Constants.torrentPort))
//            mainProxyBaseURL = URL(string: "http://".appending(cachedMainProxyBaseURLStrings.randomElement()!).appending(":").appending(HostProvider.Constants.proxyPort))
//            devTorrentIPs = cachedDevTorrentBaseURLStrings
//            devProxyIPs = cachedDevProxyBaseURLStrings
//            mainTorrentIPs = cachedMainTorrentBaseURLStrings
//            mainProxyIPs = cachedMainProxyBaseURLStrings
//            completion(true)
//            return
//        }
        getIpAddresses(for: Constants.urlTorrentDevURL) { (torrentIps) in
            if (torrentIps.count > 0) {
                progress(["type":"dev", "data" : ["proxy" :
                    ["stage" : 1,
                     "status" :
                        ["total" : 20,
                         "current" : 6
                        ]
                    ],
                          "torrent" : ["stage" : 1,
                                       "status" :
                                        ["total" : torrentIps.count,
                                         "current" : torrentIps.count - 3
                            ]
                    ]]])
                self.devTorrentIPs = torrentIps
                Storage.shared.devTorrentBaseURLStrings = torrentIps
                self.devTorrentBaseURL = URL(string: "http://".appending(torrentIps.first!).appending(":").appending(HostProvider.Constants.torrentPort))
                self.getIpAddresses(for: Constants.urlProxyDevURL, completion: { (proxyIps) in
                    if (proxyIps.count > 0) {
                        progress(["type":"dev", "data" : ["proxy" :
                            ["stage" : 3,
                             "status" :
                                ["total" : 10,
                                 "current" : 10
                                ]
                            ],
                                  "torrent" : ["stage" : 3,
                                               "status" :
                                                ["total" : 10,
                                                 "current" : 10
                                    ]
                            ]]])
                        self.devProxyIPs = proxyIps
                        Storage.shared.devProxyBaseURLStrings = proxyIps
                        self.devProxyBaseURL = URL(string: "http://".appending(proxyIps.first!).appending(":").appending(HostProvider.Constants.proxyPort))
                        self.getIpAddresses(for: Constants.urlTorrentURL) { (torrentIps) in
                            if (torrentIps.count > 0) {
                                progress(["type":"prod", "data" : ["proxy" :
                                    ["stage" : 1,
                                     "status" :
                                        ["total" : 20,
                                         "current" : 6
                                        ]
                                    ],
                                                                  "torrent" : ["stage" : 1,
                                                                               "status" :
                                                                                ["total" : torrentIps.count,
                                                                                 "current" : torrentIps.count - 3
                                                                    ]
                                    ]]])
                                self.mainTorrentIPs = torrentIps
                                Storage.shared.mainTorrentBaseURLStrings = torrentIps
                                self.mainTorrentBaseURL = URL(string: "http://".appending(torrentIps.first!).appending(":").appending(HostProvider.Constants.torrentPort))
                                self.getIpAddresses(for: Constants.urlProxyURL, completion: { (proxyIps) in
                                    if (proxyIps.count > 0) {
                                        progress(["type":"prod", "data" : ["proxy" :
                                            ["stage" : 3,
                                             "status" :
                                                ["total" : 10,
                                                 "current" : 10
                                                ]
                                            ],
                                                                          "torrent" : ["stage" : 3,
                                                                                       "status" :
                                                                                        ["total" : 10,
                                                                                         "current" : 10
                                                                            ]
                                            ]]])
                                        self.mainProxyIPs = proxyIps
                                        Storage.shared.mainProxyBaseURLStrings = proxyIps
                                        self.mainProxyBaseURL = URL(string: "http://".appending(proxyIps.first!).appending(":").appending(HostProvider.Constants.proxyPort))
                                        completion(true)
                                    } else {
                                        completion(false)
                                    }
                                })
                            } else {
                                completion(false)
                            }
                        }
                    } else {
                        completion(false)
                    }
                })
            } else {
                completion(false)
            }
        }
    }
    
    private func getIpAddresses(for host: String, completion: @escaping ([String]) -> Void) {
        let host = CFHostCreateWithName(nil,host as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        var ips = [String]()
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
            for case let theAddress as NSData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    ips.append(numAddress)
                }
            }
        }
        
        var returningIps = [String]()
        pinger.getPing(for: ips) { (ips) in
            let keys = Array(ips.keys)
            returningIps = keys.sorted(by: { (a, b) -> Bool in
                let obj1 = ips[a] // get ob associated w/ key 1
                let obj2 = ips[b] // get ob associated w/ key 2
                return obj1! < obj2!
            })
            completion(returningIps)
        }
        
    }
}
