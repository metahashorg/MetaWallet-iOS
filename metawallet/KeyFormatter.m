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
#include <CoreBitcoin/openssl/x509.h>
#include <CoreBitcoin/openssl/evp.h>
#include <CoreBitcoin/openssl/asn1.h>
#include <CoreBitcoin/BTCData.h>

#define FORMAT_ASN1 4
#define PRIVATE 1

@implementation KeyFormatter
+ (NSData *)derPrivateKey:(BTCKey *)key {
    return [self derPrivateKeyFromECKey:key.ec_key];
}

+ (NSData *)derPrivateKeyFromECKey:(EC_KEY *)key {
    EC_KEY_set_asn1_flag(key, OPENSSL_EC_NAMED_CURVE);
    char buffer[256];
    strcpy(buffer, getenv("HOME"));
    strcat(buffer, "/Documents/priv.der");
    FILE *f = fopen(buffer, "w");
    int res = i2d_ECPrivateKey_fp(f, key);
    fclose(f);
    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:buffer]];
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    return data;
}

+ (NSData *)derPublicKey:(BTCKey *)key {
    EC_KEY_set_asn1_flag(key.ec_key, OPENSSL_EC_NAMED_CURVE);
    char buffer[256];
    strcpy(buffer, getenv("HOME"));
    strcat(buffer, "/Documents/public.der");
    FILE *f = fopen(buffer, "w");
    int res = i2d_EC_PUBKEY_fp(f, key.ec_key);
    fclose(f);
    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:buffer]];
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    return data;
}

+ (nullable BTCKey *)createKeyFromDERString:(NSString *)string {
    NSData *data = BTCDataFromHex(string);
    if (data.length != 118) {
        return nil;
    }
    BTCKey *key = [[BTCKey alloc] initWithDERPrivateKey:data];
    return key;
}

+ (nullable NSData *)encrypt:(BTCKey *)key password:(NSString *)password {
    EC_KEY_set_asn1_flag(key.ec_key, OPENSSL_EC_NAMED_CURVE);
    char buffer[256];
    strcpy(buffer, getenv("HOME"));
    strcat(buffer, "/Documents/priv_enc.pem");
    FILE *f = fopen(buffer, "w");
    
    const EVP_CIPHER *cipher = EVP_aes_128_cbc();
    
    int res = PEM_write_ECPrivateKey(f, key.ec_key, cipher, NULL, 0, NULL, [password UTF8String]);
    fclose(f);
    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:buffer]];
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    return data;
}

+ (nullable BTCKey *)decryptKey:(NSString *)key withPassword:(NSString *)password {
    BIO *bio = BIO_new(BIO_s_mem());
    int len = BIO_write(bio, [key UTF8String], key.length);
    
    EC_KEY *ec_key = NULL;
    
    OpenSSL_add_all_algorithms();
    OpenSSL_add_all_ciphers();
    OpenSSL_add_all_digests();
    
    PEM_read_bio_ECPrivateKey(bio, &ec_key, NULL, [password UTF8String]);
    
    if (ec_key == NULL) {
        return nil;
    }
    
    EC_KEY_set_asn1_flag(ec_key, OPENSSL_EC_NAMED_CURVE);
    
    BTCKey *returnKey = [[BTCKey alloc] initWithDERPrivateKey:[self derPrivateKeyFromECKey:ec_key]];
    
    return returnKey;
}

int app_passwd(const char *arg1, const char *arg2, char **pass1, char **pass2)
{
    printf("boi");
    return 0;
}

@end
