//
//  MATBannerAdapter.m
//  MaticooToponAdapterLegacy
//
//  AnyThinkiOS ≤ 6.4.92：loadADWithInfo:localInfo:completion: + ATBannerCustomEvent。
//  CustomEvent strong→Ad；不用 protectLifeCycleObject，避免与 adapter.customEvent 形成环。
//

#import "MATBannerAdapter.h"
#import "MATToponSDKInitAdapter.h"
#import "MATToponLegacyBidCache.h"
#import "MATToponLegacyInitHelper.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;
@import AnyThinkSDK;
@import AnyThinkBanner;

#pragma mark - CustomEvent

@interface MATBannerCustomEvent : ATBannerCustomEvent <MATBannerAdDelegate>
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong) MATBannerAd *bannerAd;
- (void)maticoo_destroyBannerAd;
@end

@implementation MATBannerCustomEvent

- (void)maticoo_destroyBannerAd {
    MATBannerAd *ad = self.bannerAd;
    self.bannerAd = nil;
    if (!ad) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [ad destroy];
    });
}

- (void)bannerAdDidLoad:(MATBannerAd *)bannerAd {
    MaticooToponAdapterDebugLog(@"%@ banner didLoad placement=%@", MATToponAdapterLogPrefix, self.placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, nil)];
    if (self.customEventMetaDataDidLoadedBlock) {
        self.customEventMetaDataDidLoadedBlock();
    }
    // MATBannerAd 是 UIView，作为 bannerView 回传给 TopOn
    [self trackBannerAdLoaded:bannerAd adExtra:nil];
}

- (void)bannerAd:(MATBannerAd *)bannerAd didFailWithError:(NSError *)error {
    (void)bannerAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, error.localizedDescription)];
    [self trackBannerAdLoadFailed:error];
    [self maticoo_destroyBannerAd];
}

- (void)bannerAdDidClick:(MATBannerAd *)banner {
    (void)banner;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, nil)];
    [self trackBannerAdClick];
}

- (void)bannerAdDidImpression:(MATBannerAd *)banner {
    (void)banner;
    MaticooToponAdapterDebugLog(@"%@ banner impression placement=%@", MATToponAdapterLogPrefix, self.placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, nil)];
    [self trackBannerAdImpression];
}

- (void)bannerAdDismissed:(MATBannerAd *)bannerAd {
    (void)bannerAd;
    [self trackBannerAdClosed];
    [self maticoo_destroyBannerAd];
}

- (void)bannerAd:(MATBannerAd *)bannerAd showFailWithError:(NSError *)error {
    (void)bannerAd;
    // ≤6.4.92 ATBannerCustomEvent 无独立 showFailed track；记埋点即可
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, error.localizedDescription)];
    [self maticoo_destroyBannerAd];
}

- (void)dealloc {
    NSString *placementId = _placementId;
    MATBannerAd *ad = _bannerAd;
    _bannerAd = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
    MaticooToponAdapterDebugLog(@"%@ banner customEvent dealloc placement=%@", MATToponAdapterLogPrefix, placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                       des:MATToponAdapterEventDes(placementId, MATToponAdapterAdTypeBanner, nil)];
}

@end

#pragma mark - Adapter

// ATBannerAdapter.h 未纳入 AnyThinkBanner umbrella；与 IV/RV 一样只声明 ATAdAdapter，并实现 +showBanner:...
@interface MATBannerAdapter () <ATAdAdapter>
@property (nonatomic, strong) MATBannerCustomEvent *customEvent;
@end

@implementation MATBannerAdapter

- (instancetype)initWithNetworkCustomInfo:(NSDictionary *)serverInfo localInfo:(NSDictionary *)localInfo {
    self = [super init];
    if (self) {
        [MATToponSDKInitAdapter initWithCustomInfo:serverInfo localInfo:localInfo];
    }
    return self;
}

- (NSDictionary *)ensureParams:(NSDictionary *)dict {
    NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return newDict;
    }
    @try {
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]]) {
                newDict[key] = obj;
            }
        }];
    } @catch (NSException *exception) {
        (void)exception;
    }
    return newDict;
}

- (void)loadADWithInfo:(NSDictionary *)serverInfo
             localInfo:(NSDictionary *)localInfo
            completion:(void (^)(NSArray<NSDictionary *> * _Nonnull, NSError * _Nonnull))completion {
    NSDictionary *safeLocalInfo = [localInfo isKindOfClass:[NSDictionary class]] ? localInfo : nil;
    id sizeValue = safeLocalInfo[kATAdLoadingExtraBannerAdSizeKey];
    CGSize adSize = [sizeValue respondsToSelector:@selector(CGSizeValue)] ? [sizeValue CGSizeValue] : CGSizeMake(320.0f, 50.0f);

    NSString *placementIdentifier = serverInfo[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                           des:MATToponAdapterEventDes(@"", MATToponAdapterAdTypeBanner, @"placement_id is empty")];
        if (completion) {
            completion(@[], MATToponAdapterErrorInvalidPlacement(@"banner"));
        }
        return;
    }

    MATBannerCustomEvent *customEvent = [[MATBannerCustomEvent alloc] initWithInfo:serverInfo localInfo:localInfo];
    customEvent.placementId = placementIdentifier;
    customEvent.requestCompletionBlock = completion;
    self.customEvent = customEvent;

    ATUnitGroupModel *unitGroup = serverInfo[kATAdapterCustomInfoUnitGroupModelKey];
    NSString *bidId = serverInfo[kATAdapterCustomInfoBuyeruIdKey];
    NSString *cacheKey = unitGroup.unitID.length > 0 ? unitGroup.unitID : placementIdentifier;

    MaticooToponAdapterDebugLog(@"%@ banner loadAD placement=%@ bidId=%@ unitID=%@ size={%.0f,%.0f}",
          MATToponAdapterLogPrefix, placementIdentifier, bidId, cacheKey, adSize.width, adSize.height);

    __weak __typeof__(self) weakSelf = self;
    [MATToponLegacyInitHelper ensureInitializedWithServerInfo:serverInfo completion:^(NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        MATBannerCustomEvent *event = strongSelf.customEvent ?: customEvent;
        if (error) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeBanner, error.localizedDescription)];
            [event trackBannerAdLoadFailed:error];
            strongSelf.customEvent = nil;
            return;
        }

        // MATBannerAd 是 UIView：init / frame / load / destroy 必须在主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
            MATBannerCustomEvent *eventMain = strongSelfMain.customEvent ?: customEvent;
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeBanner, nil)];

            MATBannerAd *ad = [[MATBannerAd alloc] initWithPlacementID:placementIdentifier];
            ad.delegate = eventMain;
            ad.frame = CGRectMake(0, 0, adSize.width, adSize.height);
            eventMain.bannerAd = ad;

            NSMutableDictionary *extra = [NSMutableDictionary dictionary];
            if (safeLocalInfo.count > 0) {
                NSDictionary *params = strongSelfMain
                    ? [strongSelfMain ensureParams:safeLocalInfo]
                    : nil;
                if (!params) {
                    NSMutableDictionary *fallback = [NSMutableDictionary dictionary];
                    [safeLocalInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                        if ([obj isKindOfClass:[NSString class]]) {
                            fallback[key] = obj;
                        }
                    }];
                    params = fallback;
                }
                [extra addEntriesFromDictionary:params];
            }
            extra[@"source"] = MATToponAdapterMediationSourceValue;
            [ad setLocalExtra:[extra copy]];

            id canCloseObj = safeLocalInfo[@"can_close_ad"];
            if ([canCloseObj isKindOfClass:[NSNumber class]]) {
                ad.canCloseAd = [(NSNumber *)canCloseObj boolValue];
            } else if ([canCloseObj isKindOfClass:[NSString class]]) {
                ad.canCloseAd = [(NSString *)canCloseObj boolValue];
            }

            if ([bidId isKindOfClass:[NSString class]] && bidId.length > 0) {
                MATBiddingResponse *bidResponse = [MATToponLegacyBidCache bidResponseForKey:cacheKey];
                [MATToponLegacyBidCache removeBidResponseForKey:cacheKey];
                if (bidResponse.bidToken.length > 0) {
                    [MATToponLegacyBidCache attachBidResponse:bidResponse toAdObject:ad];
                    [ad loadAd:bidResponse.bidToken];
                } else {
                    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                                       des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeBanner, @"bid request failed")];
                    [eventMain trackBannerAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"banner")];
                    [eventMain maticoo_destroyBannerAd];
                    strongSelfMain.customEvent = nil;
                }
            } else {
                [ad loadAd];
            }
        });
    }];
}

+ (BOOL)adReadyWithCustomObject:(id)customObject info:(NSDictionary *)info {
    (void)info;
    if ([customObject isKindOfClass:[MATBannerAd class]]) {
        return [(MATBannerAd *)customObject isReady];
    }
    return NO;
}

+ (BOOL)isSupportAdType:(ATUnitGroupModel *)unitGroupModel {
    (void)unitGroupModel;
    return YES;
}

+ (void)showBanner:(ATBanner *)banner
            inView:(UIView *)view
presentingViewController:(UIViewController *)viewController {
    MATBannerCustomEvent *customEvent = (MATBannerCustomEvent *)banner.customEvent;
    if (customEvent) {
        customEvent.loadInputShowViewController = viewController;
    }

    UIView *bannerView = banner.bannerView;
    if (!bannerView && [banner.customObject isKindOfClass:[UIView class]]) {
        bannerView = (UIView *)banner.customObject;
    }
    if ([bannerView isKindOfClass:[MATBannerAd class]] && customEvent) {
        ((MATBannerAd *)bannerView).delegate = customEvent;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!bannerView || !view) {
            return;
        }
        [bannerView removeFromSuperview];
        bannerView.translatesAutoresizingMaskIntoConstraints = YES;
        bannerView.frame = CGRectMake(0, 0, CGRectGetWidth(bannerView.bounds) > 0 ? CGRectGetWidth(bannerView.bounds) : CGRectGetWidth(view.bounds),
                                      CGRectGetHeight(bannerView.bounds) > 0 ? CGRectGetHeight(bannerView.bounds) : CGRectGetHeight(view.bounds));
        [view addSubview:bannerView];
    });
}

#pragma mark - C2S Bidding (≤6.4.92)

+ (void)bidRequestWithPlacementModel:(ATPlacementModel *)placementModel
                      unitGroupModel:(ATUnitGroupModel *)unitGroupModel
                                info:(NSDictionary *)info
                          completion:(void (^)(ATBidInfo * _Nullable, NSError * _Nullable))completion {
    NSDictionary *networkContent = [unitGroupModel.content isKindOfClass:[NSDictionary class]] ? unitGroupModel.content : nil;
    NSString *placementIdentifier = networkContent[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        if (completion) {
            completion(nil, MATToponAdapterErrorInvalidPlacement(@"banner"));
        }
        return;
    }

    NSString *cacheKey = unitGroupModel.unitID.length > 0 ? unitGroupModel.unitID : placementIdentifier;
    MaticooToponAdapterDebugLog(@"%@ banner bidRequest zmaticooPid=%@ toponPid=%@ unitID=%@",
          MATToponAdapterLogPrefix, placementIdentifier, placementModel.placementID, cacheKey);

    NSDictionary *initServerInfo = networkContent ?: (info ?: @{});
    [MATToponLegacyInitHelper ensureInitializedWithServerInfo:initServerInfo completion:^(NSError *initError) {
        if (initError) {
            if (completion) {
                completion(nil, initError);
            }
            return;
        }

        MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
        param.placementId = placementIdentifier;
        param.adxId = @"topon_adapter_bidding";

        [MATBiddingRequest biddingRequestWithParameter:param completion:^(MATBiddingResponse * _Nullable bidResponse) {
            BOOL ok = (bidResponse != nil && bidResponse.success && bidResponse.bidToken.length > 0);
            if (!ok) {
                if (completion) {
                    completion(nil, bidResponse.error ?: MATToponAdapterErrorBiddingFailed(@"banner"));
                }
                return;
            }
            [MATToponLegacyBidCache setBidResponse:bidResponse forKey:cacheKey];
            NSTimeInterval expire = unitGroupModel.bidTokenTime > 0 ? unitGroupModel.bidTokenTime : unitGroupModel.networkTimeout;
            ATBidInfo *bidInfo = [ATBidInfo bidInfoC2SWithPlacementID:placementModel.placementID
                                                      unitGroupUnitID:unitGroupModel.unitID
                                                   adapterClassString:unitGroupModel.adapterClassString
                                                                price:[NSString stringWithFormat:@"%f", bidResponse.price]
                                                         currencyType:ATBiddingCurrencyTypeUS
                                                   expirationInterval:expire
                                                         customObject:bidResponse];
            bidInfo.networkFirmID = unitGroupModel.networkFirmID;
            if (completion) {
                completion(bidInfo, nil);
            }
        }];
    }];
}

+ (void)sendWinnerNotifyWithCustomObject:(id)customObject
                             secondPrice:(NSString *)price
                                userInfo:(NSDictionary *)userInfo {
    (void)price;
    (void)userInfo;
    MATBiddingResponse *bidResponse = [customObject isKindOfClass:[MATBiddingResponse class]]
        ? (MATBiddingResponse *)customObject
        : [MATToponLegacyBidCache bidResponseAttachedToAdObject:customObject];
    if (bidResponse) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_win"
                                                           des:MATToponAdapterEventDes(nil, MATToponAdapterAdTypeBanner, nil)];
        [MATBiddingRequest reportTrack:bidResponse];
    }
}

+ (void)sendLossNotifyWithCustomObject:(id)customObject
                              lossType:(ATBiddingLossType)lossType
                              winPrice:(NSString *)price
                              userInfo:(NSDictionary *)userInfo {
    (void)customObject;
    (void)userInfo;
    NSString *lossReason = @"other reason";
    switch (lossType) {
        case ATBiddingLossWithBiddingTimeOut:
            lossReason = @"Loss with timeout";
            break;
        case ATBiddingLossWithLowPriceInHB:
        case ATBiddingLossWithLowPriceInNormal:
            lossReason = @"Loss with low price";
            break;
        default:
            break;
    }
    NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"lossReason\":\"%@\"}",
                     (long)MATToponAdapterAdTypeBanner, MATToponAdapterMediationSourceValue, price ?: @"", lossReason];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
}

@end
