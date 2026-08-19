//
//  MATToponBaseAdapter.m
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import "MATToponBaseAdapter.h"
#import "MATToponSDKInitAdapter.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;

const NSInteger MATToponAdapterAdTypeBanner = 1;
const NSInteger MATToponAdapterAdTypeInterstitial = 2;
const NSInteger MATToponAdapterAdTypeRewardVideo = 3;
const NSInteger MATToponAdapterAdTypeNative = 4;

NSString * const MATToponAdapterMediationSourceValue = @"top_on";

NSString * const MATToponAdapterLogPrefix = @"[MATToponAdapter]";

NSString *MATToponAdapterEventDes(NSString *placementId, NSInteger adType, NSString *msg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(adType);
    dic[@"source"] = MATToponAdapterMediationSourceValue;
    if (msg.length) {
        dic[@"msg"] = msg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

NSDictionary<NSString *, id> *MATToponAdapterLoadExtraMapFromLocalInfo(NSDictionary *localInfo) {
    return [localInfo isKindOfClass:[NSDictionary class]] ? localInfo : nil;
}

NSNumber *MATToponAdapterIsMutedFromLocalInfo(NSDictionary *localInfo) {
    if (![localInfo isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id value = localInfo[@"is_muted"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([text caseInsensitiveCompare:@"true"] == NSOrderedSame) {
            return @YES;
        }
        if ([text caseInsensitiveCompare:@"false"] == NSOrderedSame) {
            return @NO;
        }
    }
    return nil;
}

NSDictionary<NSString *, id> *MATToponAdapterNativeLoadExtraMapFromLocalInfo(NSDictionary *localInfo) {
    return MATToponAdapterLoadExtraMapFromLocalInfo(localInfo);
}

void MATToponAdapterApplyCCPAFromTopOn(void) {
    // TopOn 个性化态可能在运行时变更，每次 load 前按当前值同步 CCPA。
    ATPersonalizedAdState adState = [[ATAPI sharedInstance] getPersonalizedAdState];
    if (adState != ATPersonalizedAdStateType && adState != ATNonpersonalizedAdStateType) {
        return;
    }
    MaticooAds *maticooAds = [MaticooAds shareSDK];
    if (![maticooAds respondsToSelector:@selector(setDoNotSell:)]) {
        return;
    }
    [maticooAds setDoNotSell:(adState == ATNonpersonalizedAdStateType)];
}

void MATToponAdapterApplyGDPRFromTopOn(void) {
    ATDataConsentSet consent = [[ATAPI sharedInstance] dataConsentSet];
    if (consent != ATDataConsentSetPersonalized && consent != ATDataConsentSetNonpersonalized) {
        return;
    }
    MaticooAds *maticooAds = [MaticooAds shareSDK];
    if (![maticooAds respondsToSelector:@selector(setConsentStatus:)]) {
        return;
    }
    [maticooAds setConsentStatus:(consent == ATDataConsentSetPersonalized)];
}

NSError *MATToponAdapterErrorInvalidPlacement(NSString *adFormatLabel) {
    NSString *format = adFormatLabel.length > 0 ? adFormatLabel : @"ad";
    return [NSError errorWithDomain:ATADLoadingErrorDomain
                               code:ATAdErrorCodeInvalidInputEncountered
                           userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Maticoo %@ load failed: invalid placement_id.", format],
        NSLocalizedFailureReasonErrorKey: @"placement_id is missing or invalid",
    }];
}

NSError *MATToponAdapterErrorBiddingFailed(NSString *adFormatLabel) {
    NSString *format = adFormatLabel.length > 0 ? adFormatLabel : @"ad";
    return [NSError errorWithDomain:ATADLoadingErrorDomain
                               code:ATAdErrorCodeADOfferLoadingFailed
                           userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Maticoo %@ load failed: bidding unavailable.", format],
        NSLocalizedFailureReasonErrorKey: @"bid token request failed",
    }];
}

@implementation MATToponBaseAdapter

- (void)loadADWithArgument:(ATAdMediationArgument *)argument {
    // 子类均先调 super：load 前同步 CCPA + GDPR（COPPA 仍只在 init）。
    MATToponAdapterApplyCCPAFromTopOn();
    MATToponAdapterApplyGDPRFromTopOn();
    MaticooToponAdapterDebugLog(@"%@ baseAdapter loadADWithArgument (subclass override expected)", MATToponAdapterLogPrefix);
}

- (Class)initializeClassName {
    return MATToponSDKInitAdapter.class;
}

@end
