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
/// 本次 load 成功的广告标识，show 时回传给 SDK 以展示同一个 offer。
@property (nonatomic, strong, nullable) MATMaticooIds *maticooIds;
@end

@implementation MATInterstitialCustomEvent

// 这两个属性在主线程（load 派发）和 SDK 回调线程都会写，而 TopOn 会在自己的线程读
// +adReadyWithCustomObject: / +showInterstitial:。ARC 并发读写 strong 属性会读到哨兵指针
// 0x400000000000bad0，读写必须同锁。
@synthesize interstitialAd = _interstitialAd;
@synthesize maticooIds = _maticooIds;

- (MATInterstitialAd *)interstitialAd {
    @synchronized (self) {
        return _interstitialAd;
    }
}

- (void)setInterstitialAd:(MATInterstitialAd *)interstitialAd {
    @synchronized (self) {
        _interstitialAd = interstitialAd;
    }
}

- (MATMaticooIds *)maticooIds {
    @synchronized (self) {
        return _maticooIds;
    }
}

- (void)setMaticooIds:(MATMaticooIds *)maticooIds {
    @synchronized (self) {
        _maticooIds = maticooIds;
    }
}

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd maticooIds:(MATMaticooIds *)maticooIds {
    self.maticooIds = maticooIds;
    [self mat_handleDidLoad:interstitialAd];
}

// 旧回调仅在 SDK 未走新回调时兜底，这里屏蔽废弃实现告警
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd {
    [self mat_handleDidLoad:interstitialAd];
}
#pragma clang diagnostic pop

- (void)mat_handleDidLoad:(MATInterstitialAd *)interstitialAd {
    // 以回调带回的对象为准：失败路径会把 interstitialAd 置 nil，避免 adReady / show 取到空
    if ([interstitialAd isKindOfClass:[MATInterstitialAd class]]) {
        self.interstitialAd = interstitialAd;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeInterstitial, nil)];
    if (self.customEventMetaDataDidLoadedBlock) {
        self.customEventMetaDataDidLoadedBlock();
    }
    // customObject 传 customEvent 而不是广告对象：同一 pid 的 MATInterstitialAd 是共享单例，
    // TopOn 缓存的多条 offer 会拿到同一个实例；只有 customEvent 是 per-offer 的，
    // 后续 adReady / win notify 都要靠它才能分辨在处理哪一条 offer。
    [self trackInterstitialAdLoaded:self adExtra:nil];
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
    MATInterstitialAd *ad = nil;
    @synchronized (self) {
        ad = _interstitialAd;
        _interstitialAd = nil;
    }
    ad.delegate = nil;
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

    id rawUnitGroup = serverInfo[kATAdapterCustomInfoUnitGroupModelKey];
    ATUnitGroupModel *unitGroup = [rawUnitGroup isKindOfClass:[ATUnitGroupModel class]] ? rawUnitGroup : nil;
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
            NSNumber *isMuted = MATToponAdapterIsMutedFromLocalInfo(localInfo);
            if (isMuted != nil) {
                ad.videoMute = isMuted.boolValue;
            }
            NSDictionary *extraMap = MATToponAdapterLoadExtraMapFromLocalInfo(localInfo);

            if ([bidId isKindOfClass:[NSString class]] && bidId.length > 0) {
                MATBiddingResponse *bidResponse = [MATToponLegacyBidCache bidResponseForKey:cacheKey];
                [MATToponLegacyBidCache removeBidResponseForKey:cacheKey];
                if (bidResponse.biddingRequestId.length > 0) {
                    // 挂在 customEvent 上而非共享单例 ad 上：与 customObject 保持同一个锚点，
                    // 也避免多条 offer 相互覆盖导致 win notify 上报到别的 bidResponse。
                    [MATToponLegacyBidCache attachBidResponse:bidResponse toAdObject:eventMain];
                    [ad loadAd:bidResponse.biddingRequestId extraMap:extraMap];
                } else {
                    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                                       des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeInterstitial, @"bid request failed")];
                    [eventMain trackInterstitialAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"interstitial")];
                    eventMain.interstitialAd = nil;
                    strongSelfMain.customEvent = nil;
                }
            } else {
                [ad loadAdExtraMap:extraMap];
            }
        });
    }];
}

/// customObject 是 load 时传入的 customEvent，按它持有的 Ids 判定这一条 offer 是否可展示，
/// 与 `showInterstitial:` 用的是同一个 Ids。不能退回不带 Ids 的 `isReady`：
/// 它只要共享队列里还有任意一条可展示就为 YES，会把已展示/已过期的 offer 当成可用，随后 show 必回 30114/30101。
+ (BOOL)adReadyWithCustomObject:(id)customObject info:(NSDictionary *)info {
    (void)info;
    if (![customObject isKindOfClass:[MATInterstitialCustomEvent class]]) {
        return NO;
    }
    MATInterstitialCustomEvent *customEvent = (MATInterstitialCustomEvent *)customObject;
    MATInterstitialAd *ad = customEvent.interstitialAd;
    MATMaticooIds *maticooIds = customEvent.maticooIds;
    return [ad isReadyWithMaticooIds:maticooIds];
}

+ (BOOL)isSupportAdType:(ATUnitGroupModel *)unitGroupModel {
    (void)unitGroupModel;
    return YES;
}

+ (void)showInterstitial:(ATInterstitial *)interstitial
        inViewController:(UIViewController *)viewController
                delegate:(id<ATInterstitialDelegate>)delegate {
    // interstitial.customEvent 声明为基类 ATInterstitialCustomEvent，下转到我们的子类编译期无提示；
    // 下面要访问 interstitialAd / maticooIds 等自有成员，拿到别家网络的 customEvent 会 unrecognized selector。
    MATInterstitialCustomEvent *customEvent = nil;
    if ([interstitial.customEvent isKindOfClass:[MATInterstitialCustomEvent class]]) {
        customEvent = (MATInterstitialCustomEvent *)interstitial.customEvent;
    }
    if (!customEvent) {
        NSError *error = MATToponAdapterErrorShowFailed(@"interstitial", @"customEvent is nil or of unexpected type");
        NSString *placementID = interstitial.placementModel.placementID ?: @"";
        MaticooToponAdapterDebugLog(@"%@ iv show abort: customEvent nil or wrong type=%@ placement=%@",
              MATToponAdapterLogPrefix, NSStringFromClass([interstitial.customEvent class]) ?: @"(nil)", placementID);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                           des:MATToponAdapterEventDes(placementID, MATToponAdapterAdTypeInterstitial, error.localizedDescription)];
        if ([delegate respondsToSelector:@selector(interstitialFailedToShowForPlacementID:error:extra:)]) {
            [delegate interstitialFailedToShowForPlacementID:placementID error:error extra:@{}];
        }
        return;
    }

    customEvent.delegate = delegate;
    // customObject 现在就是 customEvent 本身，广告对象统一从它身上取。
    MATInterstitialAd *ad = customEvent.interstitialAd;
    if (![ad isKindOfClass:[MATInterstitialAd class]]) {
        NSError *error = MATToponAdapterErrorShowFailed(@"interstitial", @"ad object is nil or invalid");
        MaticooToponAdapterDebugLog(@"%@ iv show abort: ad invalid placement=%@", MATToponAdapterLogPrefix, customEvent.placementId);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                           des:MATToponAdapterEventDes(customEvent.placementId, MATToponAdapterAdTypeInterstitial, error.localizedDescription)];
        [customEvent trackInterstitialAdShowFailed:error];
        return;
    }

    // show 前再拉一次 GDPR（load→show 间可能变更；CCPA 无 show-time API）
    [MATToponLegacyInitHelper applyGDPRFromTopOn];

    ad.delegate = customEvent;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATToponAdapterEventDes(customEvent.placementId, MATToponAdapterAdTypeInterstitial, nil)];
    dispatch_async(dispatch_get_main_queue(), ^{
        [ad showAdFromViewController:viewController maticooIds:customEvent.maticooIds];
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
        NSDictionary *bidExtraMap = MATToponAdapterLoadExtraMapFromLocalInfo(info);

        [MATBiddingRequest biddingRequestWithParameter:param extra:bidExtraMap completion:^(MATBiddingResponse * _Nullable bidResponse) {
            BOOL ok = (bidResponse != nil && bidResponse.success && bidResponse.biddingRequestId.length > 0);
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
