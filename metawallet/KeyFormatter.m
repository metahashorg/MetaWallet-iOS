//
//  KeyFormatter.m
//  BitcoinAddress
//
//  Created by Maxim Mamedov on 12.03.2018.
//  Copyright © 2018 Андрей Зубехин. All rights reserved.
//

#import "KeyFormatter.h"
#include <CoreBitcoin/openssl/aes.h>
#include <CoreBitcoin/openssl/pem.h>
#include <CoreBitcoin/openssl/ec.h>
#include <CoreBitcoin/openssl/x509.h>
#include <CoreBitcoin/openssl/evp.h>
#include <CoreBitcoin/openssl/asn1.h>

#define FORMAT_ASN1 4
#define PRIVATE 1

@implementation KeyFormatter
+ (NSData *)derPrivateKey:(BTCKey *)key {
    EC_KEY_set_asn1_flag(key.key, OPENSSL_EC_NAMED_CURVE);
    char buffer[256];
    strcpy(buffer, getenv("HOME"));
    strcat(buffer, "/Documents/priv.der");
    FILE *f = fopen(buffer, "w");
    int res = i2d_ECPrivateKey_fp(f, key.key);
    fclose(f);
    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:buffer]];
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    return data;
}

+ (NSData *)derPublicKey:(BTCKey *)key {
    EC_KEY_set_asn1_flag(key.key, OPENSSL_EC_NAMED_CURVE);
    char buffer[256];
    strcpy(buffer, getenv("HOME"));
    strcat(buffer, "/Documents/public.der");
    FILE *f = fopen(buffer, "w");
    int res = i2d_EC_PUBKEY_fp(f, key.key);
    fclose(f);
    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:buffer]];
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    return data;
}

+ (nullable BTCKey *)createKeyFromDERString:(NSString *)string {
    BTCKey *key = [[BTCKey alloc] initWithDERPrivateKey:BTCDataFromHex(string)];
    return key;
}

//+ (NSData *)encrypt:(BTCKey *)key password:(NSString *)password {
//    EC_KEY_set_asn1_flag(key.key, OPENSSL_EC_NAMED_CURVE);
//    char buffer[256];
//    strcpy(buffer, getenv("HOME"));
//    strcat(buffer, "/Documents/priv_enc.pem");
//    FILE *f = fopen(buffer, "w");
//    
//    const EVP_CIPHER *cipher = EVP_aes_128_cbc();
//    
//    int res = PEM_write_ECPrivateKey(f, key.key, cipher, NULL, 0, NULL, [password UTF8String]);
//    fclose(f);
//    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:buffer]];
//    NSData *data = [NSData dataWithContentsOfURL:fileURL];
//    return data;
//}

@end
