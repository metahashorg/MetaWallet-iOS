//
//  KeyFormatter.h
//  BitcoinAddress
//
//  Created by Maxim Mamedov on 12.03.2018.
//  Copyright © 2018 Андрей Зубехин. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/BTCKey.h>

@interface KeyFormatter : NSObject

NS_ASSUME_NONNULL_BEGIN

+ (NSData *)derPrivateKey:(nullable BTCKey *)key;
+ (NSData *)derPublicKey:(nullable BTCKey *)key;
+ (nullable NSData *)encrypt:(BTCKey *)key password:(NSString *)password;
+ (nullable BTCKey *)createKeyFromDERString:(NSString *)string;
+ (nullable BTCKey *)decryptKeyData:(NSData *)data withPassword:(NSString *)password;

NS_ASSUME_NONNULL_END

@end
