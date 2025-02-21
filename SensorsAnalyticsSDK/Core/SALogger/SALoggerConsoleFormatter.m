//
// SALoggerConsoleColorFormatter.m
// Logger
//
// Created by 陈玉国 on 2019/12/26.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SALoggerConsoleFormatter.h"
#import "SALogMessage.h"
#import "SALog+Private.h"

@implementation SALoggerConsoleFormatter

- (instancetype)init {
    self = [super init];
    if (self) {
        _prefix = @"";
    }
    return self;
}

- (NSString *)formattedLogMessage:(nonnull SALogMessage *)logMessage {
    NSString *prefixEmoji = @"";
    NSString *levelString = @"";
    switch (logMessage.level) {
        case SALogLevelError:
            prefixEmoji = @"❌";
            levelString = @"Error";
            break;
        case SALogLevelWarn:
            prefixEmoji = @"⚠️";
            levelString = @"Warn";
            break;
        case SALogLevelInfo:
            prefixEmoji = @"ℹ️";
            levelString = @"Info";
            break;
        case SALogLevelDebug:
            prefixEmoji = @"🛠";
            levelString = @"Debug";
            break;
        case SALogLevelVerbose:
            prefixEmoji = @"📝";
            levelString = @"Verbose";
            break;
        default:
            break;
    }
    
    NSString *dateString = [[SALog sharedLog].dateFormatter stringFromDate:logMessage.timestamp];
    NSString *line = [NSString stringWithFormat:@"%lu", logMessage.line];
    return [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ line:%@ %@\n", dateString, prefixEmoji, levelString, self.prefix, logMessage.fileName, logMessage.function, line, logMessage.message];
}

@end
