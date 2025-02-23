//
// SAViewNode.h
// SensorsAnalyticsSDK
//
// Created by 储强盛 on 2021/1/6.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SAVisualPropertiesConfig.h"

NS_ASSUME_NONNULL_BEGIN

/// 构造页面元素，用于绑定属性
@interface SAViewNode : SAViewIdentifier

#pragma mark path
/// 是否停止拼接相对路径，如果 nextResponder 为 UIViewController 则不再继续拼接
@property (nonatomic, assign, readonly, getter=isStopJoinPath) BOOL stopJoinPath;

/// 元素相对路径，依赖于 index 构造
@property (nonatomic, copy, readonly) NSString *itemPath;

/// 元素相对模糊路径，可能包含 [-]，依赖于 index 构造
@property (nonatomic, copy, readonly) NSString *similarPath;

/// 元素名称
@property (nonatomic, copy, readonly) NSString *viewName;

/**
 *  同级同类元素序号
 *
 * -1：nextResponder 不是父视图或同类元素，比如 controller.view，涉及路径不带序号
 * >= 0：elementPath 包含序号
*/
@property (nonatomic, assign) NSInteger index;

#pragma mark view
/// 节点对应 view
@property (nonatomic, weak, readonly) UIView *view;

/// 子节点
@property (nonatomic, strong) NSMutableArray<SAViewNode *> *subNodes;

/// 父视图对应节点
@property (nonatomic, weak) SAViewNode *nextNode;

- (instancetype)initWithView:(UIView *)view;

/// 视图更新，刷新 index
- (void)refreshIndex;

/// 更新所有同级同类节点 index
- (void)refreshBrotherNodeIndex;

/// 更新子节点页面名称
- (void)refreshSubNodeScreenName;

/// 构建节点链接关系
- (void)buildNodeRelation;

@end

/// 处理 UISegment 逻辑
@interface SASegmentNode : SAViewNode
@end

/// 处理 UISegmentedControl
@interface SASegmentedControlNode : SAViewNode
@end

/// UITabBarItem
@interface SATabBarButtonNode : SAViewNode

@end

// 处理 UITableViewHeaderFooterView
@interface SATableViewHeaderFooterViewNode : SAViewNode
@end

/// 处理 UITableViewCell & UICollectionViewCell
@interface SACellNode : SAViewNode
@end

/// 处理 RN 页面元素节点
@interface SARNViewNode : SAViewNode
@end

/// WKWebView 构建的元素节点
@interface SAWKWebViewNode : SAViewNode

/// 调用  JS 方法，发送自定义属性配置
/// @param configResponse 配置原始 json 数据
- (void)callJSSendVisualConfig:(NSDictionary *)configResponse;
@end

/// 需要忽略相对路径
@interface SAIgnorePathNode : SAViewNode

@end

NS_ASSUME_NONNULL_END
