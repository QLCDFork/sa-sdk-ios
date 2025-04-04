//
// SACommonUtility.m
// SensorsAnalyticsSDK
//
// Created by 储强盛 on 2018/7/26.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SACommonUtility.h" 
#import "SAValidator.h"
#import "SAIdentifier.h"
#import <CommonCrypto/CommonDigest.h>

@implementation SACommonUtility

///按字节截取指定长度字符，包括汉字
+ (NSString *)subByteString:(NSString *)string byteLength:(NSInteger )length {
    
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF8);
    NSData* data = [string dataUsingEncoding:enc];
    
    NSData *subData = [data subdataWithRange:NSMakeRange(0, length)];
    NSString*txt=[[NSString alloc] initWithData:subData encoding:enc];
    
     //utf8 汉字占三个字节，表情占四个字节，可能截取失败
    NSInteger index = 1;
    while (index <= 3 && !txt) {
        if (length > index) {
            subData = [data subdataWithRange:NSMakeRange(0, length - index)];
            txt = [[NSString alloc] initWithData:subData encoding:enc];
        }
        index ++;
    }
    
    if (!txt) {
        return string;
    }
    return txt;
}

+ (void)performBlockOnMainThread:(DISPATCH_NOESCAPE dispatch_block_t)block {
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

+ (NSString *)currentUserAgent {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"UserAgent"];
}

+ (void)saveUserAgent:(NSString *)userAgent {
    if (![SAValidator isValidString:userAgent]) {
        return;
    }
    
    NSDictionary *dictionnary = [[NSDictionary alloc] initWithObjectsAndKeys:userAgent, @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionnary];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)hashStringWithData:(NSData *)data {
    if (!data) {
        return nil;
    }
    
    /* 先转成 Base64，再计算 hash，避免直接使用 hash
     在 iOS 中 NSData 的 hash 实现，仅使用数据的前 80 个字节来计算哈希，参考：https://opensource.apple.com/source/CF/CF-635.21/CFData.c
     */
    NSString *base64String = [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
    NSNumber *hashNumber = [NSNumber numberWithUnsignedInteger:[base64String hash]];
    return [hashNumber stringValue];
}

#if TARGET_OS_IOS
+ (NSString *)appInstallSource {
    NSMutableDictionary *sources = [NSMutableDictionary dictionary];
    sources[@"idfa"] = [SAIdentifier idfa];
    sources[@"idfv"] = [SAIdentifier idfv];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *key in sources.allKeys) {
        [result addObject:[NSString stringWithFormat:@"%@=%@", key, sources[key]]];
    }
    return [result componentsJoinedByString:@"##"];
}
#endif
@end
