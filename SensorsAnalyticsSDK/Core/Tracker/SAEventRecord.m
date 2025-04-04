//
// SAEventRecord.m
// SensorsAnalyticsSDK
//
// Created by 张敏超🍎 on 2020/6/18.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAEventRecord.h"
#import "SAJSONUtil.h"
#import "SAValidator.h"
#import "SAConstants+Private.h"

@implementation SAEventRecord

static long recordIndex = 0;

- (instancetype)initWithEvent:(NSDictionary *)event type:(NSString *)type {
    if (self = [super init]) {
        _recordID = [NSString stringWithFormat:@"SA_%ld", recordIndex];
        _event = [event mutableCopy];
        _type = type;

        _encrypted = _event[kSAEncryptRecordKeyEKey] != nil;

        // 事件数据插入自定义的 ID 自增，这个 ID 在入库之前有效，入库之后数据库会生成新的 ID
        recordIndex++;
    }
    return self;
}

- (instancetype)initWithRecordID:(NSString *)recordID content:(NSString *)content {
    if (self = [super init]) {
        _recordID = recordID;

        NSMutableDictionary *eventDic = [SAJSONUtil JSONObjectWithString:content options:NSJSONReadingMutableContainers];
        if (eventDic) {
            _event = eventDic;
            _encrypted = _event[kSAEncryptRecordKeyEKey] != nil;
        }
    }
    return self;
}

- (NSString *)content {
    return [SAJSONUtil stringWithJSONObject:self.event];
}

- (BOOL)isValid {
    return self.event.count > 0;
}

- (NSString *)flushContent {
    if (![self isValid]) {
        return nil;
    }

    // 需要先添加 flush time，再进行 json 拼接
    UInt64 time = [[NSDate date] timeIntervalSince1970] * 1000;
    _event[self.encrypted ? @"flush_time" : @"_flush_time"] = @(time);
    
    return self.content;
}

- (NSString *)ekey {
    return _event[kSAEncryptRecordKeyEKey];
}

- (void)setSecretObject:(NSDictionary *)obj {
    if (![SAValidator isValidDictionary:obj]) {
        return;
    }
    [_event removeAllObjects];
    [_event addEntriesFromDictionary:obj];

    _encrypted = YES;
}

- (void)removePayload {
    if (!_event[kSAEncryptRecordKeyPayload]) {
        return;
    }
    _event[kSAEncryptRecordKeyPayloads] = [NSMutableArray arrayWithObject:_event[kSAEncryptRecordKeyPayload]];
    [_event removeObjectForKey:kSAEncryptRecordKeyPayload];
}

- (BOOL)mergeSameEKeyPayloadWithRecord:(SAEventRecord *)record {
    if (![self.ekey isEqualToString:record.ekey]) {
        return NO;
    }
    [(NSMutableArray *)_event[kSAEncryptRecordKeyPayloads] addObject:record.event[kSAEncryptRecordKeyPayload]];
    return YES;
}

@end
