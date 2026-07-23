//
//  MATToponLegacyInitHelper.h
//  MaticooToponAdapterLegacy
//
//  ≤6.4.92 无 ATBaseInitAdapter / notificationNetworkInitSuccess，
//  load / bid 前需主动等待 MaticooAds init 完成，避免 20101。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MATToponLegacyInitHelper : NSObject

/// 应用隐私透传并确保 `MaticooAds` 初始化完成（已成功则同步回调）。
+ (void)ensureInitializedWithServerInfo:(NSDictionary *)serverInfo
                             completion:(void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
