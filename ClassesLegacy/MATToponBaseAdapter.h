//
//  MATToponBaseAdapter.h
//  MaticooToponAdapterLegacy
//
//  TopOn / AnyThinkiOS ≤ 6.4.92 共用工具与常量（旧 API 无 ATBaseMediationAdapter）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *MATToponAdapterEventDes(NSString * _Nullable placementId, NSInteger adType, NSString * _Nullable msg);

FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeBanner;
FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeInterstitial;
FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeRewardVideo;
FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeNative;

FOUNDATION_EXPORT NSString * const MATToponAdapterMediationSourceValue;
FOUNDATION_EXPORT NSString * const MATToponAdapterLogPrefix;

FOUNDATION_EXPORT NSError *MATToponAdapterErrorInvalidPlacement(NSString * _Nullable adFormatLabel);
FOUNDATION_EXPORT NSError *MATToponAdapterErrorBiddingFailed(NSString * _Nullable adFormatLabel);

/// 旧 API adapter 轻量基类（NSObject）；广告类直接继承并遵循 ATAdAdapter。
@interface MATToponBaseAdapter : NSObject
@end

NS_ASSUME_NONNULL_END
