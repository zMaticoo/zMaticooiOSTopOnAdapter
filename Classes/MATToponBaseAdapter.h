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

/// 交给 load / bidding 透传的本地参数：原样返回 `localInfo`，不挑 key、不改写值。
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable MATToponAdapterLoadExtraMapFromLocalInfo(NSDictionary * _Nullable localInfo);

/// 读取 `localInfo[@"is_muted"]`；`NSNumber` 或 `"true"`/`"false"` 字符串，非法或缺省返回 nil。
FOUNDATION_EXPORT NSNumber * _Nullable MATToponAdapterIsMutedFromLocalInfo(NSDictionary * _Nullable localInfo);

/// Native load 用：与 `MATToponAdapterLoadExtraMapFromLocalInfo` 相同，原样透传（不删 `is_muted`）。
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable MATToponAdapterNativeLoadExtraMapFromLocalInfo(NSDictionary * _Nullable localInfo);

/// 从 TopOn `getPersonalizedAdState` 同步 CCPA（`setDoNotSell:`）。仅在已显式设置个性化态时写入；每次 load 入口调用。
FOUNDATION_EXPORT void MATToponAdapterApplyCCPAFromTopOn(void);

/// 从 TopOn `dataConsentSet` 同步 GDPR（`setConsentStatus:`）。仅在已显式设置 Personalized/Nonpersonalized 时写入。
/// iOS 无隐私变更回调，与 Max 类似：load / show 前主动 pull（不含 COPPA）。
FOUNDATION_EXPORT void MATToponAdapterApplyGDPRFromTopOn(void);

/// `placement_id` 缺失或非法 → `ATAdErrorCodeInvalidInputEncountered` (1014)
FOUNDATION_EXPORT NSError *MATToponAdapterErrorInvalidPlacement(NSString * _Nullable adFormatLabel);
/// Header Bidding / bid token 失败 → `ATAdErrorCodeADOfferLoadingFailed` (1003)
FOUNDATION_EXPORT NSError *MATToponAdapterErrorBiddingFailed(NSString * _Nullable adFormatLabel);

@interface MATToponBaseAdapter : ATBaseMediationAdapter

@end

NS_ASSUME_NONNULL_END
