//
//  MATToponBaseAdapter.h
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import <AnyThinkSDK/AnyThinkSDK.h>

NS_ASSUME_NONNULL_BEGIN

/// 与 Android `Utils.getAdTypeDes(adType, placementId, msg?)` 对齐的 JSON 描述串，供 `MaticooAds adapterEventReportWithEventName:des:` 使用。
FOUNDATION_EXPORT NSString *MATToponAdapterEventDes(NSString * _Nullable placementId, NSInteger adType, NSString * _Nullable msg);

FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeBanner;
FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeInterstitial;
FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeRewardVideo;
FOUNDATION_EXPORT const NSInteger MATToponAdapterAdTypeNative;

/// 埋点 JSON 与 Banner `localExtra[@"source"]` 等与 Android `ADAPTER_PLAT` 对齐的聚合标识。
FOUNDATION_EXPORT NSString * const MATToponAdapterMediationSourceValue;

/// TopOn Maticoo 适配器调试日志统一前缀；Xcode 控制台过滤关键字：`MATToponAdapter`
FOUNDATION_EXPORT NSString * const MATToponAdapterLogPrefix;

/// `placement_id` 缺失或非法 → `ATAdErrorCodeInvalidInputEncountered` (1014)
FOUNDATION_EXPORT NSError *MATToponAdapterErrorInvalidPlacement(NSString * _Nullable adFormatLabel);
/// Header Bidding / bid token 失败 → `ATAdErrorCodeADOfferLoadingFailed` (1003)
FOUNDATION_EXPORT NSError *MATToponAdapterErrorBiddingFailed(NSString * _Nullable adFormatLabel);

@interface MATToponBaseAdapter : ATBaseMediationAdapter

@end

NS_ASSUME_NONNULL_END
