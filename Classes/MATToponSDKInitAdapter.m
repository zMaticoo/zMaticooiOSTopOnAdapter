//
//  MATToponSDKInitAdapter.m
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import "MATToponSDKInitAdapter.h"
@import MaticooSDK;

@implementation MATToponSDKInitAdapter

- (void)initWithInitArgument:(ATAdInitArgument *)adInitArgument {
    // CCPA (Do Not Sell) — only configure when explicitly set
    ATPersonalizedAdState adState = [[ATAPI sharedInstance] getPersonalizedAdState];
    if (adState == ATPersonalizedAdStateType || adState == ATNonpersonalizedAdStateType) {
        [[MaticooAds shareSDK] setDoNotTrackStatus:(adState == ATNonpersonalizedAdStateType)];
    }
    
    // COPPA — only configure when age is provided
    NSNumber *age = [[ATSDKGlobalSetting sharedManager].customData valueForKey:kATCustomDataAgeKey];
    if (age != nil) {
        [[MaticooAds shareSDK] setIsAgeRestrictedUser:(age.integerValue < 13)];
    }
    
    [[MaticooAds shareSDK] setMediationName:@"topon"];
    NSString *appkey = adInitArgument.serverContentDic[@"app_key"];
    if (appkey){
        [[MaticooAds shareSDK] initSDK:appkey onSuccess:^() {
            [self notificationNetworkInitSuccess];
        } onError:^(NSError* error) {
            [self notificationNetworkInitFail:error];
        }];
    }
}


+ (NSString *)sdkVersion {
    return [[MaticooAds shareSDK] getSDKVersion];
}

+ (NSString *)adapterVersion {
    return @"2.0.0";
}

@end
