//
// SAEventLibObject.m
// SensorsAnalyticsSDK
//
// Created by yuqiang on 2021/4/6.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAEventLibObject.h"
#import "SensorsAnalyticsSDK+Private.h"
#import "SAConstants+Private.h"
#import "SAValidator.h"

/// SDK 类型
NSString * const kSAEventPresetPropertyLib = @"$lib";
/// SDK 方法
NSString * const kSAEventPresetPropertyLibMethod = @"$lib_method";
/// SDK 版本
NSString * const kSAEventPresetPropertyLibVersion = @"$lib_version";
/// 埋点详情
NSString * const kSAEventPresetPropertyLibDetail = @"$lib_detail";
/// 应用版本
NSString * const kSAEventPresetPropertyAppVersion = @"$app_version";

@implementation SAEventLibObject

- (instancetype)init {
    self = [super init];
    if (self) {
#if TARGET_OS_IOS
        _lib = @"iOS";
#elif TARGET_OS_OSX
        _lib = @"macOS";
#elif TARGET_OS_TV
        _lib = @"tvOS";
#elif TARGET_OS_WATCH
        _lib = @"watchOS";
#endif
        _method = kSALibMethodCode;
        _version = [SensorsAnalyticsSDK libVersion];
        _appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        _detail = nil;
    }
    return self;
}

- (instancetype)initWithH5Lib:(NSDictionary *)lib {
    self = [super init];
    if (self) {
        _lib = lib[kSAEventPresetPropertyLib];
        _method = lib[kSAEventPresetPropertyLibMethod];
        _version = lib[kSAEventPresetPropertyLibVersion];

        // H5 打通事件，$app_version 使用 App 的
        _appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        _detail = nil;
    }
    return self;
}

- (void)setMethod:(NSString *)method {
    if (![SAValidator isValidString:method]) {
        return;
    }
    _method = method;
}

#pragma mark - public
- (NSMutableDictionary *)jsonObject {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    properties[kSAEventPresetPropertyLib] = self.lib;
    properties[kSAEventPresetPropertyLibVersion] = self.version;
    properties[kSAEventPresetPropertyAppVersion] = self.appVersion;
    properties[kSAEventPresetPropertyLibMethod] = self.method;
    properties[kSAEventPresetPropertyLibDetail] = self.detail;
    return properties;
}

@end
