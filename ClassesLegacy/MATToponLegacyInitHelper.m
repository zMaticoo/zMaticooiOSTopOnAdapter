//
//  MATToponLegacyInitHelper.m
//  MaticooToponAdapterLegacy
//

#import "MATToponLegacyInitHelper.h"
#import "MATToponBaseAdapter.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;
@import AnyThinkSDK;

@implementation MATToponLegacyInitHelper

+ (void)applyPrivacyFromTopOn {
    MaticooAds *maticooAds = [MaticooAds shareSDK];

    ATPersonalizedAdState adState = [[ATAPI sharedInstance] getPersonalizedAdState];
    if (adState == ATPersonalizedAdStateType || adState == ATNonpersonalizedAdStateType) {
        if ([maticooAds respondsToSelector:@selector(setDoNotSell:)]) {
            [maticooAds setDoNotSell:(adState == ATNonpersonalizedAdStateType)];
        }
    }

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
}

+ (void)ensureInitializedWithServerInfo:(NSDictionary *)serverInfo
                             completion:(void (^)(NSError * _Nullable))completion {
    if (!completion) {
        return;
    }

    if ([[MaticooAds shareSDK] isInitSuccess]) {
        completion(nil);
        return;
    }

    NSString *appkey = serverInfo[@"app_key"];
    if (![appkey isKindOfClass:[NSString class]] || appkey.length == 0) {
        MaticooToponAdapterDebugLog(@"%@ ensureInit FAIL app_key invalid", MATToponAdapterLogPrefix);
        completion([NSError errorWithDomain:@"MATToponSDKInit"
                                       code:10100
                                   userInfo:@{NSLocalizedDescriptionKey: @"app_key is missing or invalid"}]);
        return;
    }

    [self applyPrivacyFromTopOn];
    [[MaticooAds shareSDK] setMediationName:@"topon"];

    // MaticooAds 支持并发 init：若正在初始化会挂到 pendingInitCallbacks，成功后一并回调。
    [[MaticooAds shareSDK] initSDK:appkey onSuccess:^{
        MaticooToponAdapterDebugLog(@"%@ ensureInit success", MATToponAdapterLogPrefix);
        completion(nil);
    } onError:^(NSError *error) {
        MaticooToponAdapterDebugLog(@"%@ ensureInit error=%@", MATToponAdapterLogPrefix, error);
        completion(error);
    }];
}

@end
