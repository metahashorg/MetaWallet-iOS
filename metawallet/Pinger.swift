//
//  Pinger.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 11/12/2018.
//  Copyright © 2018 MAD. All rights reserved.
//

import GBPing

class Pinger: NSObject, GBPingDelegate {
    
    var pings = [String : TimeInterval]()
    
    var allPingsCount = 0
    
    var completion : (([String: Double]) -> Void)?
    
    override init() {
        super.init()
    }
    
    func getPing(for hosts: [String], completion:@escaping ([String: TimeInterval]) -> Void) {
        pings.removeAll()
        allPingsCount = hosts.count
        self.completion = completion
        for host in hosts {
            let ping = GBPing.init()
            ping.timeout = 5
            ping.pingPeriod = 1
            ping.delegate = self
            ping.host = host
            
            ping.setup { (success, error) in
                if (success) {
                    ping.startPinging()
                }
            }
        }
    }
    
    func ping(_ pinger: GBPing, didReceiveReplyWith summary: GBPingSummary) {
        pinger.stop()
        let pingValue = summary.receiveDate!.timeIntervalSince(summary.sendDate!)
        pings[summary.host!] = pingValue
        if (pings.count == allPingsCount) {
            completion!(pings)
        }
    }
    
    func ping(_ pinger: GBPing, didTimeoutWith summary: GBPingSummary) {
        pinger.stop()
        pings[summary.host!] = 1000
        if (pings.count == allPingsCount) {
            completion!(pings)
        }
    }
}
