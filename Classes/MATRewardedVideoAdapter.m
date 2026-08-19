//
//  MATRewardedVideoAdapter.m
//  MaticooToponAdapter
//
//  Created by york.dong on 2026/4/17.
//

#import "MATRewardedVideoAdapter.h"
@import MaticooSDK;
#import "MaticooToponAdapterDebugLog.h"

@interface MATRewardedVideoAdapterDelegate : NSObject <MATRewardedVideoAdDelegate>
@property (strong, nonatomic) ATRewardedAdStatusBridge *adStatusBridge;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, copy) NSString *bidPriceStr;
/// 本次 load 成功的广告标识，show 时回传给 SDK 以展示同一个 offer。
@property (nonatomic, strong, nullable) MATMaticooIds *maticooIds;
@end

@implementation MATRewardedVideoAdapterDelegate

// maticooIds 在 SDK 回调线程写、在 TopOn 线程经 -adReadyRewardedWithInfo: 读，读写必须同锁。
@synthesize maticooIds = _maticooIds;

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

- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd maticooIds:(MATMaticooIds *)maticooIds {
    self.maticooIds = maticooIds;
    [self mat_handleDidLoad:rewardedVideoAd];
}

// 旧回调仅在 SDK 未走新回调时兜底，这里屏蔽废弃实现告警
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd {
    [self mat_handleDidLoad:rewardedVideoAd];
}
#pragma clang diagnostic pop

- (void)mat_handleDidLoad:(MATRewardedVideoAd *)rewardedVideoAd {
    MaticooToponAdapterDebugLog(@"%@ rv delegate=rewardedVideoAdDidLoad delegateSelf=%p placement=%@ rv=%p thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, rewardedVideoAd, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    [self.adStatusBridge atOnAdMetaLoadFinish:nil];
    if (self.bidPriceStr.length) {
        NSMutableDictionary *extra = [NSMutableDictionary dictionary];
        extra[ATAdSendC2SBidPriceKey] = self.bidPriceStr;
        extra[ATAdSendC2SCurrencyTypeKey] = @(ATBiddingCurrencyTypeUS);
        [self.adStatusBridge atOnRewardedAdLoadedExtra:extra];
    } else {
        [self.adStatusBridge atOnRewardedAdLoadedExtra:@{}];
    }
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error {
    MaticooToponAdapterDebugLog(@"%@ rv delegate=didFailWithError delegateSelf=%p placement=%@ rv=%p err=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, rewardedVideoAd, error, [NSThread currentThread], [NSThread isMainThread]);
    NSString *msg = error ? error.localizedDescription : @"";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, msg)];
    [self.adStatusBridge atOnAdLoadFailed:error adExtra:nil];
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(NSError *)error {
    NSString *msg = error ? error.localizedDescription : @"";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, msg)];
    [self.adStatusBridge atOnAdShowFailed:error extra:nil];
}

- (void)rewardedVideoAdWillLogImpression:(MATRewardedVideoAd *)rewardedVideoAd {
    MaticooToponAdapterDebugLog(@"%@ rv delegate=rewardedVideoAdWillLogImpression delegateSelf=%p placement=%@ rv=%p thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, rewardedVideoAd, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    [self.adStatusBridge atOnAdShow:nil];
}

- (void)rewardedVideoAdStarted:(MATRewardedVideoAd *)rewardedVideoAd {
    [self.adStatusBridge atOnAdVideoStart:nil];
}

- (void)rewardedVideoAdCompleted:(MATRewardedVideoAd *)rewardedVideoAd {
    [self.adStatusBridge atOnAdVideoEnd:nil];
}

- (void)rewardedVideoAdDidClick:(MATRewardedVideoAd *)rewardedVideoAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    [self.adStatusBridge atOnAdClick:nil];
}

- (void)rewardedVideoAdWillClose:(MATRewardedVideoAd *)rewardedVideoAd {
    [self.adStatusBridge atOnAdWillClosed:nil];
}

- (void)rewardedVideoAdDidClose:(MATRewardedVideoAd *)rewardedVideoAd {
    [self.adStatusBridge atOnAdClosed:nil];
}

- (void)rewardedVideoAdReward:(MATRewardedVideoAd *)rewardedVideoAd rewardInfo:(MATRewardInfo *)rewardInfo {
    MaticooToponAdapterDebugLog(@"%@ rv delegate=rewardedVideoAdReward delegateSelf=%p placement=%@ rv=%p reward=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, rewardedVideoAd, rewardInfo, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_reward" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    [self.adStatusBridge atOnRewardedVideoAdRewarded];
}

- (void)rewardedVideoAdDidSkip:(MATRewardedVideoAd *)rewardedVideoAd {
}

- (void)rewardedVideoAdEndCardShow:(MATRewardedVideoAd *)rewardedVideoAd {
}

@end

@interface MATRewardedVideoAdapter () <ATBaseRewardedAdapterProtocol>
@property (nonatomic, readonly) MATRewardedVideoAdapterDelegate *delegate;
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideoAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong) MATBiddingResponse *bidResponse;
@end

@implementation MATRewardedVideoAdapter

// 广告对象与 delegate 在主线程写，而 TopOn 会在自己的线程轮询 -adReadyRewardedWithInfo:。
// ARC 并发读写 strong 属性会读到哨兵指针 0x400000000000bad0，读写必须同锁。
// delegate 对外保持 readonly，写入方直接在 @synchronized (self) 内改 ivar。
// bidResponse 同理：bidding completion 在主线程写，TopOn 在自己的线程读 -didReceiveBidResult:。
@synthesize delegate = _delegate;
@synthesize rewardedVideoAd = _rewardedVideoAd;
@synthesize bidResponse = _bidResponse;

- (MATRewardedVideoAdapterDelegate *)delegate {
    @synchronized (self) {
        return _delegate;
    }
}

- (MATRewardedVideoAd *)rewardedVideoAd {
    @synchronized (self) {
        return _rewardedVideoAd;
    }
}

- (void)setRewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd {
    @synchronized (self) {
        _rewardedVideoAd = rewardedVideoAd;
    }
}

- (MATBiddingResponse *)bidResponse {
    @synchronized (self) {
        return _bidResponse;
    }
}

- (void)setBidResponse:(MATBiddingResponse *)bidResponse {
    @synchronized (self) {
        _bidResponse = bidResponse;
    }
}

- (void)loadADWithArgument:(ATAdMediationArgument *)argument {
    id rawPlacement = argument.serverContentDic[@"placement_id"];
    MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument ENTRY adapter=%p thread=%@ main=%d placement_id(raw)=%@ cls=%@ serverKeys=%@",
          MATToponAdapterLogPrefix,
          self,
          [NSThread currentThread],
          [NSThread isMainThread],
          rawPlacement,
          rawPlacement ? NSStringFromClass([rawPlacement class]) : @"(nil)",
          argument.serverContentDic ? [[argument.serverContentDic allKeys] componentsJoinedByString:@","] : @"(nil)");
    [super loadADWithArgument:argument];
    NSString *placementIdentifier = argument.serverContentDic[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument FAIL_EMPTY_PLACEMENT adapter=%p", MATToponAdapterLogPrefix, self);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(@"", MATToponAdapterAdTypeRewardVideo, @"placement_id is empty")];
        [self.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorInvalidPlacement(@"rewarded video") adExtra:nil];
        return;
    }
    self.placementId = placementIdentifier;
    NSDictionary *extraMap = MATToponAdapterLoadExtraMapFromLocalInfo(argument.localInfoDic);
    NSNumber *isMuted = MATToponAdapterIsMutedFromLocalInfo(argument.localInfoDic);
    MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument DISPATCH_MAIN adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
    dispatch_async(dispatch_get_main_queue(), ^{
        MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument MAIN_BLOCK_BEGIN adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, nil)];
        MATRewardedVideoAd *rewardedVideoAd = [[MATRewardedVideoAd alloc] initWithPlacementID:placementIdentifier];
        MATRewardedVideoAdapterDelegate *adDelegate = [[MATRewardedVideoAdapterDelegate alloc] init];
        adDelegate.adStatusBridge = self.adStatusBridge;
        adDelegate.placementId = placementIdentifier;
        rewardedVideoAd.delegate = adDelegate;
        if (isMuted != nil) {
            rewardedVideoAd.videoMute = isMuted.boolValue;
        }
        @synchronized (self) {
            self->_delegate = adDelegate;
            self->_rewardedVideoAd = rewardedVideoAd;
        }
        id rawTrackingInfo = argument.serverContentDic[@"tracking_info_unit_group_model"];
        ATUnitGroupModel *trackingInfoUnitGroupModel =
            [rawTrackingInfo isKindOfClass:[ATUnitGroupModel class]] ? rawTrackingInfo : nil;
        if (trackingInfoUnitGroupModel && trackingInfoUnitGroupModel.headerBidding) {
            MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument HB_BIDDING_REQUEST adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
            MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
            param.placementId = placementIdentifier;
            param.adxId = @"topon_adapter_bidding";
            __weak __typeof__(self) weakSelf = self;
            [MATBiddingRequest biddingRequestWithParameter:param extra:extraMap completion:^(MATBiddingResponse * _Nullable bidResponse) {
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                BOOL bidOk = (bidResponse != nil && bidResponse.success);
                MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument HB_BIDDING_RESPONSE adapter=%p placement=%@ success=%d price=%f token=%@",
                      MATToponAdapterLogPrefix, strongSelf, placementIdentifier, bidOk, bidResponse ? bidResponse.price : 0, bidResponse.biddingRequestId ?: @"(nil)");
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
                    if (!strongSelfMain) return;
                    if (bidOk && bidResponse.biddingRequestId.length > 0) {
                        strongSelfMain.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                        strongSelfMain.bidResponse = bidResponse;
                        [strongSelfMain.rewardedVideoAd loadAd:bidResponse.biddingRequestId extraMap:extraMap];
                    } else {
                        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, @"bid request failed")];
                        [strongSelfMain.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"rewarded video")
                                                        adExtra:nil];
                    }
                });
            }];
        } else {
            [rewardedVideoAd loadAdExtraMap:extraMap];
        }
        MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument MAIN_BLOCK_END adapter=%p placement=%@ rewardedVideoAd=%p delegate=%p",
              MATToponAdapterLogPrefix, self, placementIdentifier, rewardedVideoAd, adDelegate);
    });
}

- (void)didReceiveBidResult:(ATBidWinLossResult *)result {
    if (result.bidResultType == ATBidWinLossResultTypeWin) {
        MATBiddingResponse *bidResponse = self.bidResponse;
        NSString *winPrice = result.winPrice;
        if (winPrice == nil && bidResponse) {
            winPrice = [NSString stringWithFormat:@"%f", bidResponse.price];
        }
        
        MaticooToponAdapterDebugLog(@"%@ rv didReceiveBidResult WIN adapter=%p placement=%@ winPrice=%@ secondPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeRewardVideo, MATToponAdapterMediationSourceValue, winPrice ?: @"", result.secondPrice ?: @""];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_win" des:des];
        if (bidResponse) {
            [MATBiddingRequest reportTrack:bidResponse];
        }
    } else {
        NSString *lossReason = @"other reason";
        switch (result.lossReasonType) {
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
        MaticooToponAdapterDebugLog(@"%@ rv didReceiveBidResult LOSS adapter=%p placement=%@ lossReason=%ld winPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, (long)result.lossReasonType, result.winPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"lossReason\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeRewardVideo, MATToponAdapterMediationSourceValue, result.winPrice ?: @"", lossReason];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
    }
}

/// 按本 adapter 实例持有的 offer 判定，与 `showRewardedVideoInViewController:` 传的是同一个 Ids。
/// 不能用不带参数的 `isReady`：同一 pid 下多个 offer 共用一个 MATRewardedVideoAd，
/// 它只要队列里还有任意一条可展示就为 YES，会让 TopOn 把已展示/已过期的 offer 当成可用，
/// 随后 show 必然回 30114/30101。
- (BOOL)adReadyRewardedWithInfo:(NSDictionary *)info {
    MATRewardedVideoAd *rewardedVideoAd = self.rewardedVideoAd;
    MATMaticooIds *maticooIds = self.delegate.maticooIds;
    return [rewardedVideoAd isReadyWithMaticooIds:maticooIds];
}

- (void)showRewardedVideoInViewController:(UIViewController *)viewController {
    MATToponAdapterApplyGDPRFromTopOn();
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    dispatch_async(dispatch_get_main_queue(), ^{
        MATRewardedVideoAd *rewardedVideoAd = self.rewardedVideoAd;
        MATMaticooIds *maticooIds = self.delegate.maticooIds;
        [rewardedVideoAd showAdFromViewController:viewController maticooIds:maticooIds];
    });
}

- (void)dealloc {
    MaticooToponAdapterDebugLog(@"%@ rv MATRewardedVideoAdapter dealloc adapter=%p placementId=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, _placementId, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATToponAdapterEventDes(_placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    MATRewardedVideoAd *ad = nil;
    @synchronized (self) {
        ad = _rewardedVideoAd;
        _rewardedVideoAd = nil;
    }
    ad.delegate = nil;
}

@end
