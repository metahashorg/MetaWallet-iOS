//
//  Hashing.h
//  BitcoinAddress
//
//  Created by Maxim Mamedov on 12.03.2018.
//  Copyright © 2018 Андрей Зубехин. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>

@interface Hashing : NSObject
+ (NSData *)signData:(NSData *)data with:(BTCKey *)key;
@end
