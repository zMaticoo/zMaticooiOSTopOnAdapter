//
//  MATToponBaseAdapter.m
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import "MATToponBaseAdapter.h"
#import "MATToponSDKInitAdapter.h"
#import "MaticooToponAdapterDebugLog.h"

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
    MaticooToponAdapterDebugLog(@"%@ baseAdapter loadADWithArgument (subclass override expected)", MATToponAdapterLogPrefix);
}

- (Class)initializeClassName {
    return MATToponSDKInitAdapter.class;
}

@end
