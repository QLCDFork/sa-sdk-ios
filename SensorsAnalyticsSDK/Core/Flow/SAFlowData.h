//
// SAFlowData.h
// SensorsAnalyticsSDK
//
// Created by 张敏超🍎 on 2022/2/17.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SAConfigOptions.h"
#import "SABaseEventObject.h"

@class SAIdentifier, SAEventRecord, SAFlowData;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SAFlowState) {
    SAFlowStateNext,
    SAFlowStateStop,
    SAFlowStateError,
};

typedef NS_ENUM(NSUInteger, SAFlushGzipCode) {
    SAFlushGzipCodePlainText = 1,
    SAFlushGzipCodeEncrypt = 9,
    SAFlushGzipCodeTransportEncrypt = 13,
};

typedef void(^SAFlowDataCompletion)(SAFlowData *output);

@interface SAFlowData : NSObject

@property (nonatomic) SAFlowState state;

@property (nonatomic, copy, nullable) NSString *message;

@property (nonatomic, strong) SAConfigOptions *configOptions;

@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *param;

- (instancetype)init;

@end

#pragma mark -

@interface SAFlowData (SAParam)

#pragma mark - build
@property (nonatomic, strong, nullable) NSDictionary *properties;
@property (nonatomic, strong, nullable) SABaseEventObject *eventObject;

/// ID-Mapping 相关
@property (nonatomic, strong, nullable) SAIdentifier *identifier;

/// mark event is instant or not
@property (nonatomic,assign) BOOL isInstantEvent;

@property (nonatomic, assign) BOOL isAdsEvent;

#pragma mark - store

/// 单条数据记录
///
/// eventObject 转 json 后，构建 record，待入库
@property (nonatomic, strong, nullable) SAEventRecord *record;

/// 多条数据记录
///
/// 从库中读取的数据记录，eventObject 转 json 后，构建 record，待上传
@property (nonatomic, strong, nullable) NSArray<SAEventRecord *> *records;
@property (nonatomic, strong, nullable) NSArray<NSString *> *recordIDs;

#pragma mark - flush
@property (nonatomic, copy, nullable) NSString *json;
@property (nonatomic, strong, nullable) NSData *HTTPBody;
@property (nonatomic, assign) BOOL flushSuccess;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, copy, nullable) NSString *cookie;
@property (nonatomic, assign) NSInteger repeatCount;

@property (nonatomic, assign) SAFlushGzipCode gzipCode;

@end

NS_ASSUME_NONNULL_END
