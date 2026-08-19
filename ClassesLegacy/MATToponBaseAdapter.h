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

/// 交给 load / bidding 透传的本地参数：原样返回 `localInfo`，不挑 key、不改写值。
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable MATToponAdapterLoadExtraMapFromLocalInfo(NSDictionary * _Nullable localInfo);

/// 读取 `localInfo[@"is_muted"]`；`NSNumber` 或 `"true"`/`"false"` 字符串，非法或缺省返回 nil。
FOUNDATION_EXPORT NSNumber * _Nullable MATToponAdapterIsMutedFromLocalInfo(NSDictionary * _Nullable localInfo);

/// Native load 用：与 `MATToponAdapterLoadExtraMapFromLocalInfo` 相同，原样透传（不删 `is_muted`）。
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable MATToponAdapterNativeLoadExtraMapFromLocalInfo(NSDictionary * _Nullable localInfo);

FOUNDATION_EXPORT NSError *MATToponAdapterErrorInvalidPlacement(NSString * _Nullable adFormatLabel);
FOUNDATION_EXPORT NSError *MATToponAdapterErrorBiddingFailed(NSString * _Nullable adFormatLabel);
FOUNDATION_EXPORT NSError *MATToponAdapterErrorShowFailed(NSString * _Nullable adFormatLabel, NSString * _Nullable reason);

/// 旧 API adapter 轻量基类（NSObject）；广告类直接继承并遵循 ATAdAdapter。
@interface MATToponBaseAdapter : NSObject
@end

NS_ASSUME_NONNULL_END
