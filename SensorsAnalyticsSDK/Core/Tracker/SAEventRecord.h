//
// SAEventRecord.h
// SensorsAnalyticsSDK
//
// Created by 张敏超🍎 on 2020/6/18.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, SAEventRecordStatus) {
    SAEventRecordStatusNone,
    SAEventRecordStatusFlush,
};

@interface SAEventRecord : NSObject

@property (nonatomic, copy) NSString *recordID;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy, readonly) NSString *content;

@property (nonatomic) SAEventRecordStatus status;
@property (nonatomic, getter=isEncrypted) BOOL encrypted;
@property (nonatomic, assign) BOOL isInstantEvent;

@property (nonatomic, strong) NSMutableDictionary *event;

/// 通过 event 初始化方法
/// 主要是在 track 事件的时候使用
/// @param event 事件数据
/// @param type 上传数据类型
- (instancetype)initWithEvent:(NSDictionary *)event type:(NSString *)type;

/// 通过 recordID 和 content 进行初始化
/// 主要使用在从数据库中，获取数据时进行初始化
/// @param recordID 事件 id
/// @param content 事件 json 字符串数据
- (instancetype)initWithRecordID:(NSString *)recordID content:(NSString *)content;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isValid;

- (nullable NSString *)flushContent;

@property (nonatomic, copy, readonly) NSString *ekey;

- (void)setSecretObject:(NSDictionary *)obj;

- (void)removePayload;
- (BOOL)mergeSameEKeyPayloadWithRecord:(SAEventRecord *)record;

@end

NS_ASSUME_NONNULL_END
