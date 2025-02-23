//
// SAEventStore.m
// SensorsAnalyticsSDK
//
// Created by 张敏超🍎 on 2020/6/18.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAEventStore.h"
#import "SADatabase.h"
#import "SensorsAnalyticsSDK+Private.h"

static void * const SAEventStoreContext = (void*)&SAEventStoreContext;
static NSString * const SAEventStoreObserverKeyPath = @"isCreatedTable";

NSString * const kSADatabaseNameKey = @"database_name";
NSString * const kSADatabaseDefaultFileName = @"message-v2";

@interface SAEventStore ()

@property (nonatomic, strong) SADatabase *database;

/// store data in memory
@property (nonatomic, strong) NSMutableArray<SAEventRecord *> *recordCaches;

@end

@implementation SAEventStore

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        NSString *label = [NSString stringWithFormat:@"cn.sensorsdata.SAEventStore.%p", self];
        _serialQueue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);
        // 直接初始化，防止数据库文件，意外删除等问题
        _recordCaches = [NSMutableArray array];

        [self setupDatabase:filePath];
    }
    return self;
}

+ (instancetype)eventStoreWithFilePath:(NSString *)filePath {
    static dispatch_once_t onceToken;
    static NSMutableDictionary<NSString *, SAEventStore *> *eventStores = nil;
    dispatch_once(&onceToken, ^{
        eventStores = [NSMutableDictionary dictionary];
    });
    if (eventStores[filePath]) {
        return eventStores[filePath];
    }
    SAEventStore *eventStore = [[SAEventStore alloc] initWithFilePath:filePath];
    eventStores[filePath] = eventStore;
    return eventStore;
}

- (void)dealloc {
    [self.database removeObserver:self forKeyPath:SAEventStoreObserverKeyPath];
    self.database = nil;
}

- (void)setupDatabase:(NSString *)filePath {
    self.database = [[SADatabase alloc] initWithFilePath:filePath];
    [self.database addObserver:self forKeyPath:SAEventStoreObserverKeyPath options:NSKeyValueObservingOptionNew context:SAEventStoreContext];
}

#pragma mark - property

- (NSUInteger)count {
    return self.database.count + self.recordCaches.count;
}

- (NSUInteger)recordCountWithStatus:(SAEventRecordStatus)status {
    NSUInteger count = 0;
    for (SAEventRecord *record in self.recordCaches) {
        if (record.status == status) {
            count++;
        }
    }
    return [self.database recordCountWithStatus:status] + count;
}

#pragma mark - observe

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != SAEventStoreContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    if (![keyPath isEqualToString:SAEventStoreObserverKeyPath]) {
        return;
    }
    if (![change[NSKeyValueChangeNewKey] boolValue] || self.recordCaches.count == 0) {
        return;
    }
    // 对于内存中的数据，重试 3 次插入数据库中。
    for (NSInteger i = 0; i < 3; i++) {
        if ([self.database insertRecords:self.recordCaches]) {
            [self.recordCaches removeAllObjects];
            return;
        }
    }
}

#pragma mark - record

- (NSArray<SAEventRecord *> *)selectRecordsInCache:(NSUInteger)recordSize {
    __block NSInteger location = NSNotFound;
    [self.recordCaches enumerateObjectsUsingBlock:^(SAEventRecord * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.status != SAEventRecordStatusFlush) {
            location = idx;
            *stop = YES;
        }
    }];
    if (location == NSNotFound) {
        return nil;
    }
    NSInteger length = self.recordCaches.count - location <= recordSize ? self.recordCaches.count - location : recordSize;
    return [self.recordCaches subarrayWithRange:NSMakeRange(location, length)];
}

- (NSArray<SAEventRecord *> *)selectRecords:(NSUInteger)recordSize isInstantEvent:(BOOL)instantEvent {
    // 如果内存中存在数据，那么先上传，保证内存数据不丢失
    if (self.recordCaches.count) {
        return [self selectRecordsInCache:recordSize];
    }
    // 上传数据库中的数据
    return [self.database selectRecords:recordSize isInstantEvent:instantEvent];
}

- (BOOL)insertRecords:(NSArray<SAEventRecord *> *)records {
    return [self.database insertRecords:records];
}

- (BOOL)insertRecord:(SAEventRecord *)record {
    BOOL success = [self.database insertRecord:record];
    if (!success) {
        [self.recordCaches addObject:record];
    }
    return success;
}

- (BOOL)updateRecords:(NSArray<NSString *> *)recordIDs status:(SAEventRecordStatus)status {
    if (self.recordCaches.count == 0) {
        return [self.database updateRecords:recordIDs status:status];
    }
    // 如果加密失败，会导致 recordIDs 可能不是前 recordIDs.count 条数据，所以此处必须使用两个循环
    for (NSString *recordID in recordIDs) {
        for (SAEventRecord *record in self.recordCaches) {
            if ([recordID isEqualToString:record.recordID]) {
                record.status = status;
                break;
            }
        }
    }
    return YES;
}

- (BOOL)deleteRecords:(NSArray<NSString *> *)recordIDs {
    // 当缓存中的不存在数据时，说明数据库是正确打开，其他情况不会删除数据
    if (self.recordCaches.count == 0) {
        return [self.database deleteRecords:recordIDs];
    }
    // 删除缓存数据
    // 如果加密失败，会导致 recordIDs 可能不是前 recordIDs.count 条数据，所以此处必须使用两个循环
    // 由于加密失败的可能性较小，所以第二个循环次数不会很多
    for (NSString *recordID in recordIDs) {
        for (NSInteger index = 0; index < self.recordCaches.count; index++) {
            if ([recordID isEqualToString:self.recordCaches[index].recordID]) {
                [self.recordCaches removeObjectAtIndex:index];
                break;
            }
        }
    }
    return YES;
}

- (BOOL)deleteAllRecords {
    if (self.recordCaches.count > 0) {
        [self.recordCaches removeAllObjects];
        return YES;
    }
    return [self.database deleteAllRecords];
}

- (void)insertRecords:(NSArray<SAEventRecord *> *)records completion:(void (^)(BOOL))completion {
    dispatch_async(self.serialQueue, ^{
        completion([self insertRecords:records]);
    });
}

- (void)insertRecord:(SAEventRecord *)record completion:(void (^)(BOOL))completion {
    dispatch_async(self.serialQueue, ^{
        completion([self insertRecord:record]);
    });
}

- (void)deleteRecords:(NSArray<NSString *> *)recordIDs completion:(void (^)(BOOL))completion {
    dispatch_async(self.serialQueue, ^{
        completion([self deleteRecords:recordIDs]);
    });
}

- (void)deleteAllRecordsWithCompletion:(void (^)(BOOL))completion {
    dispatch_async(self.serialQueue, ^{
        completion([self deleteAllRecords]);
    });
}

@end
