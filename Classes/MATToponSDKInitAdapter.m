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

    // COPPA — only configure when age is provided
    NSNumber *age = [[ATSDKGlobalSetting sharedManager].customData valueForKey:kATCustomDataAgeKey];
    if (age != nil) {
        if ([maticooAds respondsToSelector:@selector(setIsAgeRestrictedUser:)]) {
            [maticooAds setIsAgeRestrictedUser:(age.integerValue < 13)];
        }
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
    return [[MaticooAds shareSDK] getSDKVersion];
}

@end
