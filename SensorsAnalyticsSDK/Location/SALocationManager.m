//
// SALocationManager.m
// SensorsAnalyticsSDK
//
// Created by 向作为 on 2018/5/7.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import <UIKit/UIKit.h>
#import "SALocationManager.h"
#import "SAConstants+Private.h"
#import "SALog.h"

static NSString * const kSAEventPresetPropertyLatitude = @"$latitude";
static NSString * const kSAEventPresetPropertyLongitude = @"$longitude";
static NSString * const kSAEventPresetPropertyCoordinateSystem = @"$geo_coordinate_system";

/* 国际通用的地球坐标系，CLLocationManager 采集定位输出结果是 WGS-84 坐标
 国内地图，比如高德、腾讯等，因为国家的保密要求，使用的是偏移后 GCJ-02坐标，戏称“火星坐标”，和 WGS84 存在坐标偏差
 */
static NSString * const kSAAppleCoordinateSystem = @"WGS84";

@interface SALocationManager() <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL isUpdatingLocation;

@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end

@implementation SALocationManager

+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    static SALocationManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [[SALocationManager alloc] init];
    });
    return manager;
}

- (void)setup {
    if (_locationManager) {
        return;
    }
    //默认设置设置精度为 100 ,也就是 100 米定位一次 ；准确性 kCLLocationAccuracyHundredMeters
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    _locationManager.distanceFilter = 100.0;

    _isUpdatingLocation = NO;

    _coordinate = kCLLocationCoordinate2DInvalid;
    [self setupListeners];
}

- (void)setConfigOptions:(SAConfigOptions *)configOptions NS_EXTENSION_UNAVAILABLE("Location not supported for iOS extensions.") {
    _configOptions = configOptions;
    self.enable = configOptions.enableLocation;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - SALocationManagerProtocol

- (void)setEnable:(BOOL)enable {
    _enable = enable;
    if (enable) {
        [self setup];
        [self startUpdatingLocation];
    } else {
        [self stopUpdatingLocation];
    }
}

- (NSDictionary *)properties {
    if (!CLLocationCoordinate2DIsValid(self.coordinate)) {
        return nil;
    }
    NSInteger latitude = self.coordinate.latitude * pow(10, 6);
    NSInteger longitude = self.coordinate.longitude * pow(10, 6);
    return @{kSAEventPresetPropertyLatitude: @(latitude), kSAEventPresetPropertyLongitude: @(longitude), kSAEventPresetPropertyCoordinateSystem: kSAAppleCoordinateSystem};
}

#pragma mark - Listener

- (void)setupListeners {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(remoteConfigManagerModelChanged:)
                               name:SA_REMOTE_CONFIG_MODEL_CHANGED_NOTIFICATION
                             object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self stopUpdatingLocation];
}

- (void)remoteConfigManagerModelChanged:(NSNotification *)sender {
    BOOL disableSDK = NO;
    @try {
        disableSDK = [[sender.object valueForKey:@"disableSDK"] boolValue];
    } @catch(NSException *exception) {
        SALogError(@"%@ error: %@", self, exception);
    }
    if (disableSDK) {
        [self stopUpdatingLocation];
    } else if (self.enable) {
        [self startUpdatingLocation];
    }
}

#pragma mark - Public

- (void)startUpdatingLocation {
    @try {
        if (self.isUpdatingLocation) {
            return;
        }
        
        // 判断当前设备定位授权的状态
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.locationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        if ((status == kCLAuthorizationStatusDenied) || (status == kCLAuthorizationStatusRestricted)) {
            SALogWarn(@"location authorization status is denied or restricted");
            return;
        }

        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager startUpdatingLocation];
        self.isUpdatingLocation = YES;
    } @catch (NSException *e) {
        SALogError(@"%@ error: %@", self, e);
    }
}

- (void)stopUpdatingLocation {
    @try {
        if (self.isUpdatingLocation) {
            [self.locationManager stopUpdatingLocation];
            self.isUpdatingLocation = NO;
        }
    }@catch (NSException *e) {
       SALogError(@"%@ error: %@", self, e);
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations API_AVAILABLE(ios(6.0), macos(10.9)) {
    self.coordinate = locations.lastObject.coordinate;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    SALogError(@"enableTrackGPSLocation error：%@", error);
}

@end
