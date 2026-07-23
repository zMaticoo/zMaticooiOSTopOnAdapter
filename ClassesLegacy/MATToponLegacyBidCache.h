//
//  MATToponLegacyBidCache.h
//  MaticooToponAdapterLegacy
//
//  C2S：bidRequest → loadAD 之间暂存 MATBiddingResponse（≤6.4.92 无 ATC2SBiddingParameterManager）。
//

#import <Foundation/Foundation.h>

@class MATBiddingResponse;

NS_ASSUME_NONNULL_BEGIN

@interface MATToponLegacyBidCache : NSObject

+ (void)setBidResponse:(MATBiddingResponse *)response forKey:(NSString *)key;
+ (nullable MATBiddingResponse *)bidResponseForKey:(NSString *)key;
+ (void)removeBidResponseForKey:(NSString *)key;

/// 将 bidResponse 挂到第三方广告对象上，供 win notify 取用。
+ (void)attachBidResponse:(nullable MATBiddingResponse *)response toAdObject:(id)adObject;
+ (nullable MATBiddingResponse *)bidResponseAttachedToAdObject:(id)adObject;

@end

NS_ASSUME_NONNULL_END
