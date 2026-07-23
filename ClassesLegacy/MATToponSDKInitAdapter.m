//
//  MATToponSDKInitAdapter.m
//  MaticooToponAdapterLegacy
//

#import "MATToponSDKInitAdapter.h"
#import "MATToponLegacyInitHelper.h"
#import "MaticooToponAdapterDebugLog.h"
#import "MATToponBaseAdapter.h"
@import MaticooSDK;

@implementation MATToponSDKInitAdapter

+ (void)initWithCustomInfo:(NSDictionary *)serverInfo localInfo:(NSDictionary *)localInfo {
    (void)localInfo;
    // 尽早触发异步 init；真正 load/bid 前仍会经 MATToponLegacyInitHelper 等待完成。
    [MATToponLegacyInitHelper ensureInitializedWithServerInfo:serverInfo completion:^(NSError *error) {
        if (error) {
            MaticooToponAdapterDebugLog(@"%@ early init error=%@", MATToponAdapterLogPrefix, error);
        }
    }];
}

- (NSString *)versionsString {
    return [[MaticooAds shareSDK] getSDKVersion] ?: ATDefaultVersion;
}

@end
