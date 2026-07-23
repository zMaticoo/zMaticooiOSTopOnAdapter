//
//  MATToponLegacyBidCache.m
//  MaticooToponAdapterLegacy
//

#import "MATToponLegacyBidCache.h"
@import MaticooSDK;
#import <objc/runtime.h>

@implementation MATToponLegacyBidCache

static NSMutableDictionary<NSString *, MATBiddingResponse *> *MATToponLegacyBidMap(void) {
    static NSMutableDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = [NSMutableDictionary dictionary];
    });
    return map;
}

+ (void)setBidResponse:(MATBiddingResponse *)response forKey:(NSString *)key {
    if (key.length == 0 || !response) {
        return;
    }
    @synchronized (MATToponLegacyBidMap()) {
        MATToponLegacyBidMap()[key] = response;
    }
}

+ (MATBiddingResponse *)bidResponseForKey:(NSString *)key {
    if (key.length == 0) {
        return nil;
    }
    @synchronized (MATToponLegacyBidMap()) {
        return MATToponLegacyBidMap()[key];
    }
}

+ (void)removeBidResponseForKey:(NSString *)key {
    if (key.length == 0) {
        return;
    }
    @synchronized (MATToponLegacyBidMap()) {
        [MATToponLegacyBidMap() removeObjectForKey:key];
    }
}

static const void *kMATToponLegacyBidResponseAssocKey = &kMATToponLegacyBidResponseAssocKey;

+ (void)attachBidResponse:(MATBiddingResponse *)response toAdObject:(id)adObject {
    if (!adObject) {
        return;
    }
    objc_setAssociatedObject(adObject, kMATToponLegacyBidResponseAssocKey, response, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (MATBiddingResponse *)bidResponseAttachedToAdObject:(id)adObject {
    if (!adObject) {
        return nil;
    }
    return objc_getAssociatedObject(adObject, kMATToponLegacyBidResponseAssocKey);
}

@end
