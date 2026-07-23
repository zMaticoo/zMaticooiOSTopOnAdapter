//
//  MATRewardedVideoAdapter.m
//  MaticooToponAdapterLegacy
//
//  AnyThinkiOS ≤ 6.4.92：loadADWithInfo:localInfo:completion: + ATRewardedVideoCustomEvent。
//  CustomEvent strong→Ad，Ad.delegate weak→CustomEvent；
//  不使用 protectLifeCycleObject，避免与 adapter.customEvent 形成环。
//

#import "MATRewardedVideoAdapter.h"
#import "MATToponSDKInitAdapter.h"
#import "MATToponLegacyBidCache.h"
#import "MATToponLegacyInitHelper.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;
@import AnyThinkSDK;
@import AnyThinkRewardedVideo;

#pragma mark - CustomEvent

@interface MATRewardedVideoCustomEvent : ATRewardedVideoCustomEvent <MATRewardedVideoAdDelegate>
@property (nonatomic, copy) NSString *placementId;
/// 由 CustomEvent 持有广告对象；TopOn 持有 CustomEvent 即可保活到 close。
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideoAd;
@end

@implementation MATRewardedVideoCustomEvent

- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd {
    MaticooToponAdapterDebugLog(@"%@ rv didLoad placement=%@", MATToponAdapterLogPrefix, self.placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    if (self.customEventMetaDataDidLoadedBlock) {
        self.customEventMetaDataDidLoadedBlock();
    }
    [self trackRewardedVideoAdLoaded:rewardedVideoAd adExtra:nil];
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, error.localizedDescription)];
    [self trackRewardedVideoAdLoadFailed:error];
    self.rewardedVideoAd = nil;
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(NSError *)error {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, error.localizedDescription)];
    [self trackRewardedVideoAdPlayEventWithError:error];
    self.rewardedVideoAd = nil;
}

- (void)rewardedVideoAdWillLogImpression:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    [self trackRewardedVideoAdShow];
}

- (void)rewardedVideoAdStarted:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [self trackRewardedVideoAdVideoStart];
}

- (void)rewardedVideoAdCompleted:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [self trackRewardedVideoAdVideoEnd];
}

- (void)rewardedVideoAdDidClick:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    [self trackRewardedVideoAdClick];
}

- (void)rewardedVideoAdWillClose:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
}

- (void)rewardedVideoAdDidClose:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [self trackRewardedVideoAdCloseRewarded:self.rewardGranted extra:@{}];
    self.rewardedVideoAd = nil;
}

- (void)rewardedVideoAdReward:(MATRewardedVideoAd *)rewardedVideoAd rewardInfo:(MATRewardInfo *)rewardInfo {
    (void)rewardedVideoAd;
    (void)rewardInfo;
    MaticooToponAdapterDebugLog(@"%@ rv reward callback placement=%@ grantedBefore=%d",
          MATToponAdapterLogPrefix, self.placementId, self.rewardGranted);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_reward"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    // ≤6.4.92：发奖前回传前需将 rewardGranted 置 YES，否则 close 时 rewarded=NO，且 reward success 可能被丢弃
    self.rewardGranted = YES;
    void (^notify)(void) = ^{
        [self trackRewardedVideoAdRewarded];
    };
    if ([NSThread isMainThread]) {
        notify();
    } else {
        dispatch_async(dispatch_get_main_queue(), notify);
    }
}

- (void)rewardedVideoAdDidSkip:(MATRewardedVideoAd *)rewardedVideoAd {}
- (void)rewardedVideoAdEndCardShow:(MATRewardedVideoAd *)rewardedVideoAd {}

- (void)dealloc {
    NSString *placementId = _placementId;
    _rewardedVideoAd = nil;
    MaticooToponAdapterDebugLog(@"%@ rv customEvent dealloc placement=%@", MATToponAdapterLogPrefix, placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                       des:MATToponAdapterEventDes(placementId, MATToponAdapterAdTypeRewardVideo, nil)];
}

@end

#pragma mark - Adapter

@interface MATRewardedVideoAdapter () <ATAdAdapter>
/// 仅 load 阶段由 adapter 抓住；load 成功后 TopOn 持有 customEvent，adapter 可提前释放。
@property (nonatomic, strong) MATRewardedVideoCustomEvent *customEvent;
@end

@implementation MATRewardedVideoAdapter

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
                                                           des:MATToponAdapterEventDes(@"", MATToponAdapterAdTypeRewardVideo, @"placement_id is empty")];
        if (completion) {
            completion(@[], MATToponAdapterErrorInvalidPlacement(@"rewarded video"));
        }
        return;
    }

    MATRewardedVideoCustomEvent *customEvent = [[MATRewardedVideoCustomEvent alloc] initWithInfo:serverInfo localInfo:localInfo];
    customEvent.placementId = placementIdentifier;
    customEvent.requestCompletionBlock = completion;
    self.customEvent = customEvent;

    ATUnitGroupModel *unitGroup = serverInfo[kATAdapterCustomInfoUnitGroupModelKey];
    NSString *bidId = serverInfo[kATAdapterCustomInfoBuyeruIdKey];
    NSString *cacheKey = unitGroup.unitID.length > 0 ? unitGroup.unitID : placementIdentifier;

    MaticooToponAdapterDebugLog(@"%@ rv loadAD placement=%@ bidId=%@ unitID=%@",
          MATToponAdapterLogPrefix, placementIdentifier, bidId, cacheKey);

    __weak __typeof__(self) weakSelf = self;
    [MATToponLegacyInitHelper ensureInitializedWithServerInfo:serverInfo completion:^(NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        MATRewardedVideoCustomEvent *event = strongSelf.customEvent ?: customEvent;
        if (error) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, error.localizedDescription)];
            [event trackRewardedVideoAdLoadFailed:error];
            strongSelf.customEvent = nil;
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
            MATRewardedVideoCustomEvent *eventMain = strongSelfMain.customEvent ?: customEvent;
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, nil)];

            MATRewardedVideoAd *ad = [[MATRewardedVideoAd alloc] initWithPlacementID:placementIdentifier];
            ad.delegate = eventMain;
            eventMain.rewardedVideoAd = ad;

            if ([bidId isKindOfClass:[NSString class]] && bidId.length > 0) {
                MATBiddingResponse *bidResponse = [MATToponLegacyBidCache bidResponseForKey:cacheKey];
                [MATToponLegacyBidCache removeBidResponseForKey:cacheKey];
                if (bidResponse.bidToken.length > 0) {
                    [MATToponLegacyBidCache attachBidResponse:bidResponse toAdObject:ad];
                    [ad loadAd:bidResponse.bidToken];
                } else {
                    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                                       des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, @"bid request failed")];
                    [eventMain trackRewardedVideoAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"rewarded video")];
                    eventMain.rewardedVideoAd = nil;
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
    if ([customObject isKindOfClass:[MATRewardedVideoAd class]]) {
        return [(MATRewardedVideoAd *)customObject isReady];
    }
    return NO;
}

+ (BOOL)isSupportAdType:(ATUnitGroupModel *)unitGroupModel {
    (void)unitGroupModel;
    return YES;
}

+ (void)showRewardedVideo:(ATRewardedVideo *)rewardedVideo
         inViewController:(UIViewController *)viewController
                 delegate:(id<ATRewardedVideoDelegate>)delegate {
    MATRewardedVideoCustomEvent *customEvent = (MATRewardedVideoCustomEvent *)rewardedVideo.customEvent;
    customEvent.delegate = delegate;
    MATRewardedVideoAd *ad = rewardedVideo.customObject;
    if (![ad isKindOfClass:[MATRewardedVideoAd class]]) {
        ad = customEvent.rewardedVideoAd;
    }
    if ([ad isKindOfClass:[MATRewardedVideoAd class]] && customEvent) {
        ad.delegate = customEvent;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATToponAdapterEventDes(customEvent.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
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
            completion(nil, MATToponAdapterErrorInvalidPlacement(@"rewarded video"));
        }
        return;
    }

    NSString *cacheKey = unitGroupModel.unitID.length > 0 ? unitGroupModel.unitID : placementIdentifier;
    MaticooToponAdapterDebugLog(@"%@ rv bidRequest zmaticooPid=%@ toponPid=%@ unitID=%@ contentKeys=%@",
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
                    completion(nil, bidResponse.error ?: MATToponAdapterErrorBiddingFailed(@"rewarded video"));
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
                                                         customObject:nil];
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
    MATBiddingResponse *bidResponse = [MATToponLegacyBidCache bidResponseAttachedToAdObject:customObject];
    if (bidResponse) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_win"
                                                           des:MATToponAdapterEventDes(nil, MATToponAdapterAdTypeRewardVideo, nil)];
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
                     (long)MATToponAdapterAdTypeRewardVideo, MATToponAdapterMediationSourceValue, price ?: @"", lossReason];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
}

@end
