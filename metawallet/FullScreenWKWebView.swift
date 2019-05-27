//
//  FullscreenWebView.swift
//  metawallet
//
//  Created by Maxim MAMEDOV on 09/04/2019.
//  Copyright © 2019 MAD. All rights reserved.
//

import Foundation
import WebKit

class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
