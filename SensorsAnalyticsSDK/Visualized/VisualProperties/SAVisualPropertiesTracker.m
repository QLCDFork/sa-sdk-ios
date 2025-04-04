//
// SAVisualPropertiesTracker.m
// SensorsAnalyticsSDK
//
// Created by 储强盛 on 2021/1/6.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAVisualPropertiesTracker.h"
#import <UIKit/UIKit.h>
#import "SAVisualPropertiesConfigSources.h"
#import "SAVisualizedUtils.h"
#import "UIView+SAAutoTrack.h"
#import "UIView+SAViewPath.h"
#import "SAVisualizedDebugLogTracker.h"
#import "SAVisualizedLogger.h"
#import "SAJavaScriptBridgeManager.h"
#import "SAAlertController.h"
#import "UIView+SAVisualProperties.h"
#import "SAJSONUtil.h"
#import "SALog.h"
#import "SAConstants+Private.h"
#import "UIView+SAElementPosition.h"

@interface SAVisualPropertiesTracker()

@property (atomic, strong, readwrite) SAViewNodeTree *viewNodeTree;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) SAVisualPropertiesConfigSources *configSources;
@property (nonatomic, strong) SAVisualizedDebugLogTracker *debugLogTracker;
@property (nonatomic, strong) SAAlertController *enableLogAlertController;
@end

@implementation SAVisualPropertiesTracker

- (instancetype)initWithConfigSources:(SAVisualPropertiesConfigSources *)configSources {
    self = [super init];
    if (self) {
        _configSources = configSources;
        NSString *serialQueueLabel = [NSString stringWithFormat:@"com.sensorsdata.SAVisualPropertiesTracker.%p", self];
        _serialQueue = dispatch_queue_create([serialQueueLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        _viewNodeTree = [[SAViewNodeTree alloc] initWithQueue:_serialQueue];
    }
    return self;
}

#pragma mark build ViewNodeTree
- (void)didMoveToSuperviewWithView:(UIView *)view {
    /*节点更新和属性遍历，共用同一个队列
     防止触发点击事件，同时进行页面跳转，尚未遍历结束节点元素就被移除了
     */
    dispatch_async(self.serialQueue, ^{
        [self.viewNodeTree didMoveToSuperviewWithView:view];
    });
}

- (void)didMoveToWindowWithView:(UIView *)view {
    /*节点更新和属性遍历，共用同一个队列
     防止触发点击事件，同时进行页面跳转，尚未遍历结束节点元素就被移除了
     */
    dispatch_async(self.serialQueue, ^{
        [self.viewNodeTree didMoveToWindowWithView:view];
    });
}

- (void)didAddSubview:(UIView *)subview {
    dispatch_async(self.serialQueue, ^{
        [self.viewNodeTree didAddSubview:subview];
    });
}

- (void)becomeKeyWindow:(UIWindow *)window {
    if (!window.isKeyWindow) {
        return;
    }
    dispatch_async(self.serialQueue, ^{
        [self.viewNodeTree becomeKeyWindow:window];
    });
}

- (void)enterRNViewController:(UIViewController *)viewController {
    [self.viewNodeTree refreshRNViewScreenNameWithViewController:viewController];
}

#pragma mark - visualProperties

#pragma mark App visualProperties
// 采集元素自定义属性
- (void)visualPropertiesWithView:(UIView *)view completionHandler:(void (^)(NSDictionary *_Nullable visualProperties))completionHandler {

    // 如果列表定义事件不限定元素位置，则只能在当前列表内元素（点击元素所在位置）添加属性。所以此时的属性元素位置，和点击元素位置必须相同
    NSString *clickPosition = [view sensorsdata_elementPosition];
    
    NSInteger pageIndex = [SAVisualizedUtils pageIndexWithView:view];
    // 单独队列执行耗时查询
    dispatch_async(self.serialQueue, ^{
        /* 添加日志信息
         在队列执行，防止快速点击导致的顺序错乱
         */
        if (self.debugLogTracker) {
            [self.debugLogTracker addTrackEventWithView:view withConfig:self.configSources.originalResponse];
        }
        
        /* 查询事件配置
         因为涉及是否限定位置，一个 view 可能被定义多个事件
         */
        SAViewNode *viewNode = view.sensorsdata_viewNode;
        NSArray <SAVisualPropertiesConfig *>*allEventConfigs = [self.configSources propertiesConfigsWithViewNode:viewNode];

        NSMutableDictionary *allEventProperties = [NSMutableDictionary dictionary];
        NSMutableArray *webPropertiesConfigs = [NSMutableArray array];
        for (SAVisualPropertiesConfig *config in allEventConfigs) {
            if (config.webProperties.count > 0) {
                [webPropertiesConfigs addObjectsFromArray:config.webProperties];
            }

            // 查询 native 属性
            NSDictionary *properties = [self queryAllPropertiesWithPropertiesConfig:config clickPosition:clickPosition pageIndex:pageIndex];
            if (properties.count > 0) {
                [allEventProperties addEntriesFromDictionary:properties];
            }
        }

        // 不包含 H5 属性配置
        if (webPropertiesConfigs.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(allEventProperties.count > 0 ? allEventProperties : nil);
            });
            return;
        }

        // 查询多个 WebView 内所有自定义属性
        [self queryMultiWebViewPropertiesWithConfigs:webPropertiesConfigs viewNode:viewNode completionHandler:^(NSDictionary * _Nullable properties) {
            if (properties.count > 0) {
                [allEventProperties addEntriesFromDictionary:properties];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(allEventProperties.count > 0 ? allEventProperties : nil);
            });
        }];
    });
}

/// 根据配置查询元素属性信息
/// @param config 配置信息
/// @param clickPosition 点击元素位置
/// @param pageIndex 页面序号
- (nullable NSDictionary *)queryAllPropertiesWithPropertiesConfig:(SAVisualPropertiesConfig *)config clickPosition:(NSString *)clickPosition pageIndex:(NSInteger)pageIndex {

    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    for (SAVisualPropertiesPropertyConfig *propertyConfig in config.properties) {
        // 合法性校验
        if (propertyConfig.regular.length == 0 || propertyConfig.name.length == 0 || propertyConfig.elementPath.length == 0) {
            NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"property configuration" message:@"property %@ invalid", propertyConfig];
            SALogError(@"SAVisualPropertiesPropertyConfig error, %@", logMessage);
            continue;
        }
        
        // 事件是否限定元素位置，影响属性元素的匹配逻辑
        propertyConfig.limitPosition = config.event.limitPosition;
        
        /* 属性配置，保存点击位置
         属性配置中保存当前点击元素位置，用于属性元素筛选
         如果属性元素为当前点击 Cell 嵌套 Cell 的内嵌元素，则不需使用当前位置匹配
         路径示例如下：
         Cell 本身路径：UIView/UITableView[0]/SACommonTableViewCell[0][-]
         Cell 嵌套普通元素路径：UIView/UITableView[0]/SACommonTableViewCell[0][-]/UITableViewCellContentView[0]/UIButton[0]
         Cell 嵌套 Cell 路径：UIView/UITableView[1]/TableViewCollectionViewCell[0][0]/UITableViewCellContentView[0]/UICollectionView[0]/HomeOptionsCollecionCell[0][-]
         Cell 嵌套 Cell 再嵌套元素路径：UIView/UITableView[1]/TableViewCollectionViewCell[0][0]/UITableViewCellContentView[0]/UICollectionView[0]/HomeOptionsCollecionCell[0][-]/UIView[0]/UIView[0]/UIButton[0]
         
         备注: cell 内嵌 button 的点击事件，那么 cell 内嵌 其他 view，也支持这种不限定位置的约束和筛选逻辑，path 示例如下:
         UIView/UITableView[0]/SATestTableViewCell[0][-]/UITableViewCellContentView[0]/UIStackView[0]/UIButton[1]
         UIView/UITableView[0]/SATestTableViewCell[0][-]/UITableViewCellContentView[0]/UIStackView[0]/UILabel[0]
         */
        
        NSRange propertyRange = [propertyConfig.elementPath rangeOfString:@"[-]"];
        NSRange eventRange = [config.event.elementPath rangeOfString:@"[-]"];
        
        if (propertyRange.location != NSNotFound && eventRange.location != NSNotFound) {
            NSString *propertyElementPathPrefix = [propertyConfig.elementPath substringToIndex:propertyRange.location];
            NSString *eventElementPathPrefix = [config.event.elementPath substringToIndex:eventRange.location];
            if ([propertyElementPathPrefix isEqualToString:eventElementPathPrefix]) {
                propertyConfig.clickElementPosition = clickPosition;
            }
        }

        // 页面序号，仅匹配当前页面元素
        propertyConfig.pageIndex = pageIndex;

        // 根据修改后的配置，查询属性值
        NSDictionary *property = [self queryPropertiesWithPropertyConfig:propertyConfig];
        if (!property) {
            continue;
        }
        [properties addEntriesFromDictionary:property];
    }
    return properties;
}

/// 解析属性值
- (NSString *)analysisPropertyWithView:(UIView *)view propertyConfig:(SAVisualPropertiesPropertyConfig *)config {
    
    // 获取元素内容，主线程执行
    __block NSString *content = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        content = view.sensorsdata_propertyContent;
    });
    
    if (content.length == 0) {
        // 打印 view 需要在主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"parse property" message:@"property %@ failed to get element content, %@", config.name, view];
            SALogWarn(@"%@", logMessage);
        });
        return nil;
    }
    
    // 根据正则解析属性
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:config.regular options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    
    // 仅取出第一条匹配记录
    NSTextCheckingResult *firstResult = [regex firstMatchInString:content options:0 range:NSMakeRange(0, [content length])];
    if (!firstResult) {
        NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"parse property" message:@"element content %@ regex parsing property failed, property name is: %@，regex is: %@", content, config.name, config.regular];
        SALogWarn(@"%@", logMessage);
        return nil;
    }
    
    NSString *value = [content substringWithRange:firstResult.range];
    return value;
}

/// 根据属性配置查询属性值
- (nullable NSDictionary *)queryPropertiesWithPropertyConfig:(SAVisualPropertiesPropertyConfig *)propertyConfig {
    // 1. 获取属性元素
    UIView *view = [self.viewNodeTree viewWithPropertyConfig:propertyConfig];
    if (!view) {
        NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"get property element" message:@"property %@ property element not found", propertyConfig.name];
        SALogDebug(@"%@", logMessage);
        return nil;
    }

    // 2. 根据属性元素，解析属性值
    NSString *propertyValue = [self analysisPropertyWithView:view propertyConfig:propertyConfig];
    if (!propertyValue) {
        return nil;
    }

    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    // 3. 属性类型转换
    // 字符型属性
    if (propertyConfig.type == SAVisualPropertyTypeString) {
        properties[propertyConfig.name] = propertyValue;
        return [properties copy];
    }

    // 数值型属性
    NSDecimalNumber *propertyNumber = [NSDecimalNumber decimalNumberWithString:propertyValue];
    // 判断转换后是否为 NAN
    if ([propertyNumber isEqualToNumber:NSDecimalNumber.notANumber]) {
        NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"parse property" message:@"property %@ the result after regex parsing is: %@, numeric conversion failed", propertyConfig.name, propertyValue];
        SALogWarn(@"%@", logMessage);
        return nil;
    }
    properties[propertyConfig.name] = propertyNumber;
    return [properties copy];
}

/// 根据配置，查询 Native 属性
- (void)queryVisualPropertiesWithConfigs:(NSArray <NSDictionary *>*)propertyConfigs completionHandler:(void (^)(NSDictionary *_Nullable properties))completionHandler {

    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *allEventProperties = [NSMutableDictionary dictionary];
        for (NSDictionary *propertyConfigDic in propertyConfigs) {
            SAVisualPropertiesPropertyConfig *propertyConfig = [[SAVisualPropertiesPropertyConfig alloc] initWithDictionary:propertyConfigDic];

            /* 查询 native 属性
             如果存在多个 page 页面，这里可能查询错误
             */
            NSDictionary *property = [self queryPropertiesWithPropertyConfig:propertyConfig];
            if (property.count > 0) {
                [allEventProperties addEntriesFromDictionary:property];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(allEventProperties);
        });
    });
}


#pragma mark webView visualProperties
/// 查询多个 webView 内自定义属性
- (void)queryMultiWebViewPropertiesWithConfigs:(NSArray <NSDictionary *>*)propertyConfigs viewNode:(SAViewNode *)viewNode completionHandler:(void (^)(NSDictionary *_Nullable properties))completionHandler {
    if (propertyConfigs.count == 0) {
        completionHandler(nil);
        return;
    }

    // 事件元素为 App，属性元素可能存在于多个 WebView
    NSDictionary <NSString *, NSArray *>* groupPropertyConfigs = [self groupMultiWebViewWithConfigs:propertyConfigs];

    NSMutableDictionary *webProperties = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    for (NSArray *configArray in groupPropertyConfigs.allValues) {

        dispatch_group_enter(group);
        [self queryCurrentWebViewPropertiesWithConfigs:configArray viewNode:viewNode completionHandler:^(NSDictionary * _Nullable properties) {
            if (properties.count > 0) {
                [webProperties addEntriesFromDictionary:properties];
            }
            dispatch_group_leave(group);
        }];
    }

    // 多个 webview 属性查询完成，返回结果
    dispatch_group_notify(group, self.serialQueue, ^{
        completionHandler([webProperties copy]);
    });
}

/// 查询当前 webView 内自定义属性
- (void)queryCurrentWebViewPropertiesWithConfigs:(NSArray <NSDictionary *> *)propertyConfigs viewNode:(SAViewNode *)viewNode completionHandler:(void (^)(NSDictionary *_Nullable properties))completionHandler {

    NSDictionary *config = [propertyConfigs firstObject];
    SAVisualPropertiesPropertyConfig *propertyConfig = [[SAVisualPropertiesPropertyConfig alloc] initWithDictionary:config];
    // 设置页面信息，准确查找 webView
    propertyConfig.screenName = viewNode.screenName;
    propertyConfig.pageIndex = viewNode.pageIndex;

    UIView *view = [self.viewNodeTree viewWithPropertyConfig:propertyConfig];
    if (![view isKindOfClass:WKWebView.class]) {
        NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"get property element" message:@"App embedded H5 property %@ did not find the corresponding WKWebView element", propertyConfig.name];
        SALogDebug(@"%@", logMessage);
        completionHandler(nil);
        return;
    }

    WKWebView *webView = (WKWebView *)view;
    NSMutableDictionary *webMessageInfo = [NSMutableDictionary dictionary];
    webMessageInfo[@"platform"] = @"ios";
    webMessageInfo[kSAWebVisualProperties] = propertyConfigs;

    // 注入待查询的属性配置信息
    NSString *javaScriptSource = [SAJavaScriptBridgeBuilder buildCallJSMethodStringWithType:SAJavaScriptCallJSTypeWebVisualProperties jsonObject:webMessageInfo];
    if (!javaScriptSource) {
        completionHandler(nil);
        return;
    }
    // 使用 webview 调用 JS 方法，获取属性，主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView evaluateJavaScript:javaScriptSource completionHandler:^(id _Nullable results, NSError *_Nullable error) {
            // 类型判断
            if ([results isKindOfClass:NSDictionary.class]) {
                completionHandler(results);
            } else {
                NSString *logMessage = [SAVisualizedLogger buildLoggerMessageWithTitle:@"parse property" message:@"the JS method %@ was called, failed to parse App embedded H5 property", javaScriptSource];
                SALogDebug(@"%@", logMessage);
                completionHandler(nil);
            }
        }];
    });
}

/// 对属性配置按照 webview 进行分组处理
- (NSDictionary <NSString *, NSArray *> *)groupMultiWebViewWithConfigs:(NSArray <NSDictionary *>*)propertyConfigs {
    NSMutableDictionary *groupPropertyConfigs = [NSMutableDictionary dictionary];
    for (NSDictionary * propertyConfigDic in propertyConfigs) {
        NSString *webViewElementPath = propertyConfigDic[@"webview_element_path"];
        if (!webViewElementPath) {
            continue;
        }

        // 当前 webview 的属性配置
        NSMutableArray <NSDictionary *>* configs = groupPropertyConfigs[webViewElementPath];
        if (!configs) {
            configs = [NSMutableArray array];
            groupPropertyConfigs[webViewElementPath] = configs;
        }
        [configs addObject:propertyConfigDic];
    }
    return [groupPropertyConfigs copy];
}

#pragma mark - logInfos
/// 开始采集调试日志
- (void)enableCollectDebugLog:(BOOL)enable {
    if (!enable) { // 关闭日志采集
        self.debugLogTracker = nil;
        self.enableLogAlertController = nil;
        return;
    }
    // 已经开启日志采集
    if (self.debugLogTracker) {
        return;
    }
    
    // 开启日志采集
    if (SensorsAnalyticsSDK.sharedInstance.configOptions.enableLog) {
        self.debugLogTracker = [[SAVisualizedDebugLogTracker alloc] init];
        return;
    }
    
    // 避免重复弹框
    if (self.enableLogAlertController) {
        return;
    }
    // 未开启 enableLog，弹框提示
    __weak SAVisualPropertiesTracker *weakSelf = self;
    self.enableLogAlertController = [[SAAlertController alloc] initWithTitle:SALocalizedString(@"SAAlertHint") message:SALocalizedString(@"SAVisualizedEnableLogHint") preferredStyle:SAAlertControllerStyleAlert];
    [self.enableLogAlertController addActionWithTitle:SALocalizedString(@"SAVisualizedEnableLogAction") style:SAAlertActionStyleDefault handler:^(SAAlertAction * _Nonnull action) {
        [[SensorsAnalyticsSDK sharedInstance] enableLog:YES];
        
        weakSelf.debugLogTracker = [[SAVisualizedDebugLogTracker alloc] init];
    }];
    [self.enableLogAlertController addActionWithTitle:SALocalizedString(@"SAVisualizedTemporarilyDisabled") style:SAAlertActionStyleCancel handler:nil];
    [self.enableLogAlertController show];
}

- (NSArray<NSDictionary *> *)logInfos {
    return [self.debugLogTracker.debugLogInfos copy];
}

@end


