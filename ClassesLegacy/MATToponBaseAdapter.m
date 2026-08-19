//
//  MATToponBaseAdapter.m
//  MaticooToponAdapterLegacy
//

#import "MATToponBaseAdapter.h"
@import AnyThinkSDK;

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

NSError *MATToponAdapterErrorShowFailed(NSString *adFormatLabel, NSString *reason) {
    NSString *format = adFormatLabel.length > 0 ? adFormatLabel : @"ad";
    NSString *detail = reason.length > 0 ? reason : @"unknown show failure";
    return [NSError errorWithDomain:ATADLoadingErrorDomain
                               code:ATAdErrorCodeADOfferNotFound
                           userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Maticoo %@ show failed: %@.", format, detail],
        NSLocalizedFailureReasonErrorKey: detail,
    }];
}

@implementation MATToponBaseAdapter
@end
