//
//  MATInterstitialAdapter.m
//  MaticooToponAdapterLegacy
//
//  AnyThinkiOS ≤ 6.4.92：loadADWithInfo:localInfo:completion: + ATInterstitialCustomEvent。
//  CustomEvent strong→Ad，Ad.delegate weak→CustomEvent；不用 protectLifeCycleObject，避免与 adapter.customEvent 形成环。
//

#import "MATInterstitialAdapter.h"
#import "MATToponSDKInitAdapter.h"
#import "MATToponLegacyBidCache.h"
#import "MATToponLegacyInitHelper.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;
@import AnyThinkSDK;
@import AnyThinkInterstitial;

#pragma mark - CustomEvent

@interface MATInterstitialCustomEvent : ATInterstitialCustomEvent <MATInterstitialAdDelegate>
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong) MATInterstitialAd *interstitialAd;
@end

@implementation MATInterstitialCustomEvent

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeInterstitial, nil)];
    if (self.customEventMetaDataDidLoadedBlock) {
        self.customEventMetaDataDidLoadedBlock();
    }
    [self trackInterstitialAdLoaded:interstitialAd adExtra:nil];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error {
    (void)interstitialAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeInterstitial, error.localizedDescription)];
    [self trackInterstitialAdLoadFailed:error];
    self.interstitialAd = nil;
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd {
    (void)interstitialAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeInterstitial, nil)];
    [self trackInterstitialAdShow];
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd {
    (void)interstitialAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeInterstitial, nil)];
    [self trackInterstitialAdClick];
}

- (void)interstitialAdDidClose:(MATInterstitialAd *)interstitialAd {
    (void)interstitialAd;
    [self trackInterstitialAdClose:nil];
    self.interstitialAd = nil;
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error {
    (void)interstitialAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeInterstitial, error.localizedDescription)];
    [self trackInterstitialAdShowFailed:error];
    self.interstitialAd = nil;
}

- (void)interstitialAdWillClose:(MATInterstitialAd *)interstitialAd {
    (void)interstitialAd;
}

- (void)interstitialAdDidSkip:(MATInterstitialAd *)interstitialAd {}
- (void)interstitialAdEndCardShow:(MATInterstitialAd *)interstitialAd {}

- (void)dealloc {
    NSString *placementId = _placementId;
    _interstitialAd = nil;
    MaticooToponAdapterDebugLog(@"%@ iv customEvent dealloc placement=%@", MATToponAdapterLogPrefix, placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                       des:MATToponAdapterEventDes(placementId, MATToponAdapterAdTypeInterstitial, nil)];
}

@end

#pragma mark - Adapter

@interface MATInterstitialAdapter () <ATAdAdapter>
@property (nonatomic, strong) MATInterstitialCustomEvent *customEvent;
@end

@implementation MATInterstitialAdapter

- (instancetype)initWithNetworkCustomInfo:(NSDictionary *)serverInfo localInfo:(NSDictionary *)localInfo {
    self = [super init];
    if (self) {
        [MATToponSDKInitAdapter initWithCustomInfo:serverInfo localInfo:localInfo];
    }
    return self;
}

- (void)loadADWithInfo:(NSDictionary *)serverInfo
             localInfo:(NSDictionary *)localInfo
            completion:(void (^)(NSArray<NSDictionary *> * _Nonnull, NSError * _Nonnull))completion {
    NSString *placementIdentifier = serverInfo[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                           des:MATToponAdapterEventDes(nil, MATToponAdapterAdTypeInterstitial, @"placement_id is empty")];
        if (completion) {
            completion(@[], MATToponAdapterErrorInvalidPlacement(@"interstitial"));
        }
        return;
    }

    MATInterstitialCustomEvent *customEvent = [[MATInterstitialCustomEvent alloc] initWithInfo:serverInfo localInfo:localInfo];
    customEvent.placementId = placementIdentifier;
    customEvent.requestCompletionBlock = completion;
    self.customEvent = customEvent;

    ATUnitGroupModel *unitGroup = serverInfo[kATAdapterCustomInfoUnitGroupModelKey];
    NSString *bidId = serverInfo[kATAdapterCustomInfoBuyeruIdKey];
    NSString *cacheKey = unitGroup.unitID.length > 0 ? unitGroup.unitID : placementIdentifier;

    MaticooToponAdapterDebugLog(@"%@ iv loadAD placement=%@ bidId=%@ unitID=%@",
          MATToponAdapterLogPrefix, placementIdentifier, bidId, cacheKey);

    __weak __typeof__(self) weakSelf = self;
    [MATToponLegacyInitHelper ensureInitializedWithServerInfo:serverInfo completion:^(NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        MATInterstitialCustomEvent *event = strongSelf.customEvent ?: customEvent;
        if (error) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeInterstitial, error.localizedDescription)];
            [event trackInterstitialAdLoadFailed:error];
            strongSelf.customEvent = nil;
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
            MATInterstitialCustomEvent *eventMain = strongSelfMain.customEvent ?: customEvent;
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeInterstitial, nil)];

            MATInterstitialAd *ad = [[MATInterstitialAd alloc] initWithPlacementID:placementIdentifier];
            ad.delegate = eventMain;
            eventMain.interstitialAd = ad;

            if ([bidId isKindOfClass:[NSString class]] && bidId.length > 0) {
                MATBiddingResponse *bidResponse = [MATToponLegacyBidCache bidResponseForKey:cacheKey];
                [MATToponLegacyBidCache removeBidResponseForKey:cacheKey];
                if (bidResponse.bidToken.length > 0) {
                    [MATToponLegacyBidCache attachBidResponse:bidResponse toAdObject:ad];
                    [ad loadAd:bidResponse.bidToken];
                } else {
                    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                                       des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeInterstitial, @"bid request failed")];
                    [eventMain trackInterstitialAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"interstitial")];
                    eventMain.interstitialAd = nil;
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
    if ([customObject isKindOfClass:[MATInterstitialAd class]]) {
        return [(MATInterstitialAd *)customObject isReady];
    }
    return NO;
}

+ (BOOL)isSupportAdType:(ATUnitGroupModel *)unitGroupModel {
    (void)unitGroupModel;
    return YES;
}

+ (void)showInterstitial:(ATInterstitial *)interstitial
        inViewController:(UIViewController *)viewController
                delegate:(id<ATInterstitialDelegate>)delegate {
    MATInterstitialCustomEvent *customEvent = (MATInterstitialCustomEvent *)interstitial.customEvent;
    customEvent.delegate = delegate;
    MATInterstitialAd *ad = interstitial.customObject;
    if (![ad isKindOfClass:[MATInterstitialAd class]]) {
        ad = customEvent.interstitialAd;
    }
    if ([ad isKindOfClass:[MATInterstitialAd class]] && customEvent) {
        ad.delegate = customEvent;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATToponAdapterEventDes(customEvent.placementId, MATToponAdapterAdTypeInterstitial, nil)];
    dispatch_async(dispatch_get_main_queue(), ^{
        [ad showAdFromViewController:viewController];
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
            completion(nil, MATToponAdapterErrorInvalidPlacement(@"interstitial"));
        }
        return;
    }

    NSString *cacheKey = unitGroupModel.unitID.length > 0 ? unitGroupModel.unitID : placementIdentifier;
    MaticooToponAdapterDebugLog(@"%@ iv bidRequest zmaticooPid=%@ toponPid=%@ unitID=%@ contentKeys=%@",
          MATToponAdapterLogPrefix,
          placementIdentifier,
          placementModel.placementID,
          cacheKey,
          networkContent ? [[networkContent allKeys] componentsJoinedByString:@","] : @"(nil)");

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
                    completion(nil, bidResponse.error ?: MATToponAdapterErrorBiddingFailed(@"interstitial"));
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
                                                           des:MATToponAdapterEventDes(nil, MATToponAdapterAdTypeInterstitial, nil)];
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
                     (long)MATToponAdapterAdTypeInterstitial, MATToponAdapterMediationSourceValue, price ?: @"", lossReason];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
}

@end
