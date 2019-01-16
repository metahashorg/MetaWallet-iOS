//
//  KeyFormatter.h
//  BitcoinAddress
//
//  Created by Maxim Mamedov on 12.03.2018.
//  Copyright © 2018 Андрей Зубехин. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>

@interface KeyFormatter : NSObject

+ (NSData *)derPrivateKey:(BTCKey *)key;
+ (NSData *)derPublicKey:(BTCKey *)key;
+ (NSData *)encrypt:(BTCKey *)key password:(NSString *)password;
+ (nullable BTCKey *)createKeyFromDERString:(NSString *)string;

@end
