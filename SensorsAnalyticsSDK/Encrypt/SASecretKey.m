//
// SASecretKey.m
// SensorsAnalyticsSDK
//
// Created by wenquan on 2021/6/26.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SASecretKey.h"
#import "SAAlgorithmProtocol.h"

@interface SASecretKey ()

/// 密钥版本
@property (nonatomic, assign) NSInteger version;

/// 密钥值
@property (nonatomic, copy) NSString *key;

/// 对称加密类型
@property (nonatomic, copy) NSString *symmetricEncryptType;

/// 非对称加密类型
@property (nonatomic, copy) NSString *asymmetricEncryptType;

@end

@implementation SASecretKey

- (instancetype)initWithKey:(NSString *)key
                    version:(NSInteger)version
      asymmetricEncryptType:(NSString *)asymmetricEncryptType
       symmetricEncryptType:(NSString *)symmetricEncryptType {
    self = [super init];
    if (self) {
        self.version = version;
        self.key = key;
        [self updateAsymmetricType:asymmetricEncryptType symmetricType:symmetricEncryptType];

    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.version forKey:@"version"];
    [coder encodeObject:self.key forKey:@"key"];
    [coder encodeObject:self.symmetricEncryptType forKey:@"symmetricEncryptType"];
    [coder encodeObject:self.asymmetricEncryptType forKey:@"asymmetricEncryptType"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.version = [coder decodeIntegerForKey:@"version"];
        self.key = [coder decodeObjectForKey:@"key"];

        NSString *symmetricType = [coder decodeObjectForKey:@"symmetricEncryptType"];
        NSString *asymmetricType = [coder decodeObjectForKey:@"asymmetricEncryptType"];
        [self updateAsymmetricType:asymmetricType symmetricType:symmetricType];
    }
    return self;
}

- (void)updateAsymmetricType:(NSString *)asymmetricType symmetricType:(NSString *)symmetricType {
    // 兼容老版本保存的秘钥
    if (!symmetricType) {
        self.symmetricEncryptType = kSAAlgorithmTypeAES;
    } else {
        self.symmetricEncryptType = symmetricType;
    }

    // 兼容老版本保存的秘钥
    if (!asymmetricType) {
        BOOL isECC = [self.key hasPrefix:kSAAlgorithmTypeECC];
        self.asymmetricEncryptType = isECC ? kSAAlgorithmTypeECC : kSAAlgorithmTypeRSA;
    } else {
        self.asymmetricEncryptType = asymmetricType;
    }
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    SASecretKey *key = [[[self class] allocWithZone:zone] init];
    key.key = self.key;
    key.version = self.version;
    key.symmetricEncryptType = self.symmetricEncryptType;
    key.asymmetricEncryptType = self.asymmetricEncryptType;
    return key;
}

@end
