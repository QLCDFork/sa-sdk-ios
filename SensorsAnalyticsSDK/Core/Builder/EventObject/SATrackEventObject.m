//
// SATrackEventObject.m
// SensorsAnalyticsSDK
//
// Created by yuqiang on 2021/4/6.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SATrackEventObject.h"
#import "SAConstants+Private.h"
#import "SAValidator.h"
#import "SALog.h"
#import "SensorsAnalyticsSDK+Private.h"
#import "SASessionProperty.h"

@implementation SATrackEventObject

- (instancetype)initWithEventId:(NSString *)eventId {
    self = [super init];
    if (self) {
        self.eventId = eventId ? [NSString stringWithFormat:@"%@", eventId] : nil;
    }
    return self;
}

- (void)validateEventWithError:(NSError **)error {
    [SAValidator validKey:self.eventId error:error];
}

@end

@implementation SASignUpEventObject

- (instancetype)initWithEventId:(NSString *)eventId {
    self = [super initWithEventId:eventId];
    if (self) {
        self.type = SAEventTypeSignup;
    }
    return self;
}

- (instancetype)initWithH5Event:(NSDictionary *)event {
    self = [super initWithH5Event:event];
    if (self) {
        self.type = SAEventTypeSignup;
    }
    return self;
}

- (NSMutableDictionary *)jsonObject {
    NSMutableDictionary *jsonObject = [super jsonObject];
    jsonObject[kSAEventOriginalId] = self.originalId;
    return jsonObject;
}

- (BOOL)isSignUp {
    return YES;
}

// $SignUp 事件不添加该属性
- (void)addModuleProperties:(NSDictionary *)properties {
}

@end

@implementation SACustomEventObject

@end

@implementation SAAutoTrackEventObject

- (instancetype)initWithEventId:(NSString *)eventId {
    self = [super initWithEventId:eventId];
    if (self) {
        self.type = SAEventTypeTrack;
        self.lib.method = kSALibMethodAuto;
    }
    return self;
}

@end

@implementation SAPresetEventObject

@end

/// 绑定 ID 事件
@implementation SABindEventObject

- (instancetype)initWithEventId:(NSString *)eventId {
    self = [super initWithEventId:eventId];
    if (self) {
        self.type = SAEventTypeBind;
    }
    return self;
}

- (instancetype)initWithH5Event:(NSDictionary *)event {
    self = [super initWithH5Event:event];
    if (self) {
        self.type = SAEventTypeBind;
    }
    return self;
}

@end

/// 解绑 ID 事件
@implementation SAUnbindEventObject

- (instancetype)initWithEventId:(NSString *)eventId {
    self = [super initWithEventId:eventId];
    if (self) {
        self.type = SAEventTypeUnbind;
    }
    return self;
}

- (instancetype)initWithH5Event:(NSDictionary *)event {
    self = [super initWithH5Event:event];
    if (self) {
        self.type = SAEventTypeUnbind;
    }
    return self;
}

@end
