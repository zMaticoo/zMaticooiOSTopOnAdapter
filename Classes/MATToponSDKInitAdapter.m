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
    MaticooAds *maticooAds = [MaticooAds shareSDK];

    // CCPA (Do Not Sell) — only configure when explicitly set
    ATPersonalizedAdState adState = [[ATAPI sharedInstance] getPersonalizedAdState];
    if (adState == ATPersonalizedAdStateType || adState == ATNonpersonalizedAdStateType) {
        if ([maticooAds respondsToSelector:@selector(setDoNotSell:)]) {
            [maticooAds setDoNotSell:(adState == ATNonpersonalizedAdStateType)];
        }
    }

    // GDPR (Consent) — only configure when explicitly set via TopOn setDataConsentSet:
    ATDataConsentSet consent = [[ATAPI sharedInstance] dataConsentSet];
    if (consent == ATDataConsentSetPersonalized || consent == ATDataConsentSetNonpersonalized) {
        if ([maticooAds respondsToSelector:@selector(setConsentStatus:)]) {
            [maticooAds setConsentStatus:(consent == ATDataConsentSetPersonalized)];
        }
    }

    id ageValue = [[ATSDKGlobalSetting sharedManager].customData valueForKey:kATCustomDataAgeKey];
    if ([ageValue isKindOfClass:[NSNumber class]]) {
        if ([maticooAds respondsToSelector:@selector(setIsAgeRestrictedUser:)]) {
            [maticooAds setIsAgeRestrictedUser:([(NSNumber *)ageValue integerValue] < 13)];
        }
    }
    
    [[MaticooAds shareSDK] setMediationName:@"topon"];
    // 后台 JSON 配错类型时（如 NSNumber/NSArray）直接传入 -initSDK: 会 unrecognized selector 崩溃，先做 isKindOfClass 校验。
    NSString *appkey = adInitArgument.serverContentDic[@"app_key"];
    if ([appkey isKindOfClass:[NSString class]] && appkey.length > 0) {
        [[MaticooAds shareSDK] initSDK:appkey onSuccess:^() {
            [self notificationNetworkInitSuccess];
        } onError:^(NSError* error) {
            [self notificationNetworkInitFail:error];
        }];
    } else {
        [self notificationNetworkInitFail:[NSError errorWithDomain:@"MATToponSDKInit"
                                                              code:10100
                                                          userInfo:@{NSLocalizedDescriptionKey:@"app_key is missing or invalid"}]];
    }
}


+ (NSString *)sdkVersion {
    return [[MaticooAds shareSDK] getSDKVersion];
}

+ (NSString *)adapterVersion {
    return [[MaticooAds shareSDK] getSDKVersion];
}

@end
