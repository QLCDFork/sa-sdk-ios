//
// UIApplication+SAAutoTrack.m
// SensorsAnalyticsSDK
//
// Created by 王灼洲 on 17/3/22.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "UIApplication+SAAutoTrack.h"
#import "SALog.h"
#import "SensorsAnalyticsSDK.h"
#import "UIView+SAAutoTrack.h"
#import "SAConstants+Private.h"
#import "SensorsAnalyticsSDK+Private.h"
#import "UIViewController+SAAutoTrack.h"
#import "SAAutoTrackUtils.h"
#import "SAAutoTrackManager.h"
#import "UIView+SensorsAnalytics.h"

@implementation UIApplication (AutoTrack)

- (BOOL)sa_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {

    BOOL ret = YES;

    // 针对 tab 切换，采集切换后的页面信息，先执行系统 sendAction 完成页面切换
    BOOL isTabBar = [to isKindOfClass:UITabBar.class] || [to isKindOfClass:UITabBarController.class];
    /*
     默认先执行 AutoTrack
     如果先执行原点击处理逻辑，可能已经发生页面 push 或者 pop，导致获取当前 ViewController 不正确
     可以通过 UIView 扩展属性 sensorsAnalyticsAutoTrackAfterSendAction，来配置 AutoTrack 是发生在原点击处理函数之前还是之后
     */
    BOOL sensorsAnalyticsAutoTrackAfterSendAction = [from isKindOfClass:[UIView class]] && [(UIView *)from sensorsAnalyticsAutoTrackAfterSendAction];
    BOOL autoTrackAfterSendAction = isTabBar || sensorsAnalyticsAutoTrackAfterSendAction;

    if (autoTrackAfterSendAction) {
        ret = [self sa_sendAction:action to:to from:from forEvent:event];
    }

    @try {
        [self sa_track:action to:to from:from forEvent:event];
    } @catch (NSException *exception) {
        SALogError(@"%@ error: %@", self, exception);
    }

    if (!autoTrackAfterSendAction) {
        ret = [self sa_sendAction:action to:to from:from forEvent:event];
    }

    return ret;
}

- (void)sa_track:(SEL)action to:(id)to from:(NSObject *)from forEvent:(UIEvent *)event {
    // 过滤多余点击事件，因为当 from 为 UITabBarItem，event 为 nil， 采集下次类型为 button 的事件。
    if ([from isKindOfClass:UITabBarItem.class] || [from isKindOfClass:UIBarButtonItem.class]) {
        return;
    }

    NSObject<SAAutoTrackViewProperty> *object = (NSObject<SAAutoTrackViewProperty> *)from;
    if ([object isKindOfClass:[UISwitch class]] ||
        [object isKindOfClass:[UIStepper class]] ||
        [object isKindOfClass:[UISegmentedControl class]] ||
        [object isKindOfClass:[UIPageControl class]]) {
        [SAAutoTrackManager.defaultManager.appClickTracker autoTrackEventWithView:(UIView *)object];
        return;
    }

    if ([event isKindOfClass:[UIEvent class]] && event.type == UIEventTypeTouches && [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
        [SAAutoTrackManager.defaultManager.appClickTracker autoTrackEventWithView:(UIView *)object];
    }
}

@end
