//
// SAAppViewScreenTracker.m
// SensorsAnalyticsSDK
//
// Created by 张敏超🍎 on 2021/4/27.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAAppViewScreenTracker.h"
#import "SensorsAnalyticsSDK+Private.h"
#import "UIViewController+SAAutoTrack.h"
#import "SAAppLifecycle.h"
#import "SAConstants+Private.h"
#import "SAValidator.h"
#import "SAAutoTrackUtils.h"
#import "SAReferrerManager.h"
#import "SAModuleManager.h"
#import "SensorsAnalyticsSDK+SAAutoTrack.h"
#import "SAUIProperties.h"

@interface SAAppViewScreenTracker ()

@property (nonatomic, strong) NSMutableArray<UIViewController *> *launchedPassivelyControllers;

@end

@implementation SAAppViewScreenTracker

- (instancetype)init {
    self = [super init];
    if (self) {
        _launchedPassivelyControllers = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Override

- (NSString *)eventId {
    return kSAEventNameAppViewScreen;
}

- (BOOL)shouldTrackViewController:(UIViewController *)viewController {
    if ([self isViewControllerIgnored:viewController]) {
        return NO;
    }
    if ([self isBlackListContainsViewController:viewController]) {
        return NO;
    }
    if ([viewController conformsToProtocol:@protocol(SAScreenAutoTracker)] && [viewController respondsToSelector:@selector(isIgnoredAutoTrackViewScreen)]) {
        return ![(UIViewController<SAScreenAutoTracker> *)viewController isIgnoredAutoTrackViewScreen];
    }
    return YES;
}

#pragma mark - Public Methods

- (void)autoTrackEventWithViewController:(UIViewController *)viewController {
    if (!viewController) {
        return;
    }
    
    if (self.isIgnored) {
        return;
    }
    
    //过滤用户设置的不被AutoTrack的Controllers
    if (![self shouldTrackViewController:viewController]) {
        return;
    }

    if (self.isPassively) {
        [self.launchedPassivelyControllers addObject:viewController];
        return;
    }
    
    NSDictionary *eventProperties = [self buildWithViewController:viewController properties:nil autoTrack:YES];
    [self trackAutoTrackEventWithProperties:eventProperties];
}

- (void)trackEventWithViewController:(UIViewController *)viewController properties:(NSDictionary<NSString *, id> *)properties {
    if (!viewController || ![viewController isKindOfClass:UIViewController.class]) {
        return;
    }

    if ([self isBlackListContainsViewController:viewController]) {
        return;
    }

    NSDictionary *eventProperties = [self buildWithViewController:viewController properties:properties autoTrack:NO];
    [self trackPresetEventWithProperties:eventProperties];
}

- (void)trackEventWithURL:(NSString *)url properties:(NSDictionary<NSString *,id> *)properties {
    NSDictionary *eventProperties = [[SAReferrerManager sharedInstance] propertiesWithURL:url eventProperties:properties];
    [self trackPresetEventWithProperties:eventProperties];
}

- (void)trackEventOfLaunchedPassively {
    if (self.launchedPassivelyControllers.count == 0) {
        return;
    }

    if (self.isIgnored) {
        return;
    }

    for (UIViewController *vc in self.launchedPassivelyControllers) {
        if ([self shouldTrackViewController:vc]) {
            NSDictionary *eventProperties = [self buildWithViewController:vc properties:nil autoTrack:YES];
            [self trackAutoTrackEventWithProperties:eventProperties];
        }
    }
    [self.launchedPassivelyControllers removeAllObjects];
}

#pragma mark – Private Methods

- (BOOL)isBlackListContainsViewController:(UIViewController *)viewController {
    NSDictionary *autoTrackBlackList = [self autoTrackViewControllerBlackList];
    NSDictionary *appViewScreenBlackList = autoTrackBlackList[kSAEventNameAppViewScreen];
    return [self isViewController:viewController inBlackList:appViewScreenBlackList];
}

- (NSDictionary *)buildWithViewController:(UIViewController *)viewController properties:(NSDictionary<NSString *, id> *)properties autoTrack:(BOOL)autoTrack {
    NSMutableDictionary *eventProperties = [[NSMutableDictionary alloc] init];

    NSDictionary *autoTrackProperties = [SAUIProperties propertiesWithViewController:viewController];
    [eventProperties addEntriesFromDictionary:autoTrackProperties];

    if (autoTrack) {
        // App 通过 DeepLink 启动时第一个页面浏览事件会添加 utms 属性
        // 只需要处理全埋点的页面浏览事件
        [eventProperties addEntriesFromDictionary:SAModuleManager.sharedInstance.utmProperties];
        [SAModuleManager.sharedInstance clearUtmProperties];
    }

    if ([SAValidator isValidDictionary:properties]) {
        [eventProperties addEntriesFromDictionary:properties];
    }

    NSString *currentURL;
    if ([viewController conformsToProtocol:@protocol(SAScreenAutoTracker)] && [viewController respondsToSelector:@selector(getScreenUrl)]) {
        UIViewController<SAScreenAutoTracker> *screenAutoTrackerController = (UIViewController<SAScreenAutoTracker> *)viewController;
        currentURL = [screenAutoTrackerController getScreenUrl];
    }
    currentURL = [currentURL isKindOfClass:NSString.class] ? currentURL : NSStringFromClass(viewController.class);

    // 添加 $url 和 $referrer 页面浏览相关属性
    NSDictionary *newProperties = [SAReferrerManager.sharedInstance propertiesWithURL:currentURL eventProperties:eventProperties];

    return newProperties;
}

@end
