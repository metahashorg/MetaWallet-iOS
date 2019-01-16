//
//  Hashing.m
//  BitcoinAddress
//
//  Created by Maxim Mamedov on 12.03.2018.
//  Copyright © 2018 Андрей Зубехин. All rights reserved.
//

#import "Hashing.h"
#import <CommonCrypto/CommonCrypto.h>
#include <CoreBitcoin/openssl/ecdsa.h>

@implementation Hashing
+ (NSData *)signData:(NSData *)data with:(BTCKey *)key {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([data bytes], (CC_LONG)[data length], digest);
    unsigned int size = ECDSA_size(key.key);
    unsigned char signature[size];
    int result = ECDSA_sign(0, digest, CC_SHA256_DIGEST_LENGTH, signature, &size, key.key);
    return [NSData dataWithBytes:signature length:size];    
}
     
@end
