//
//  WebKitHelper.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 16/01/2019.
//  Copyright © 2019 MAD. All rights reserved.
//

import WebKit

final class WebCacheCleaner {
    class func clean() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        print("[WebCacheCleaner] All cookies deleted")
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                print("[WebCacheCleaner] Record \(record) deleted")
            }
        }
        HostProvider.shared.proxyBaseURL = nil
        HostProvider.shared.torrentBaseURL = nil
    }
}
