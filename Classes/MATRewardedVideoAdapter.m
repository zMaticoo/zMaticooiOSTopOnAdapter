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
@end

@implementation MATRewardedVideoAdapterDelegate

- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd {
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
    MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument DISPATCH_MAIN adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
    dispatch_async(dispatch_get_main_queue(), ^{
        MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument MAIN_BLOCK_BEGIN adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, nil)];
        self->_rewardedVideoAd = [[MATRewardedVideoAd alloc] initWithPlacementID:placementIdentifier];
        self->_delegate = [[MATRewardedVideoAdapterDelegate alloc] init];
        self->_delegate.adStatusBridge = self.adStatusBridge;
        self->_delegate.placementId = placementIdentifier;
        self->_rewardedVideoAd.delegate = self->_delegate;
        id rawTrackingInfo = argument.serverContentDic[@"tracking_info_unit_group_model"];
        ATUnitGroupModel *trackingInfoUnitGroupModel =
            [rawTrackingInfo isKindOfClass:[ATUnitGroupModel class]] ? rawTrackingInfo : nil;
        if (trackingInfoUnitGroupModel && trackingInfoUnitGroupModel.headerBidding) {
            MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument HB_BIDDING_REQUEST adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
            MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
            param.placementId = placementIdentifier;
            param.adxId = @"topon_adapter_bidding";
            __weak __typeof__(self) weakSelf = self;
            [MATBiddingRequest biddingRequestWithParameter:param completion:^(MATBiddingResponse * _Nullable bidResponse) {
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                BOOL bidOk = (bidResponse != nil && bidResponse.success);
                MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument HB_BIDDING_RESPONSE adapter=%p placement=%@ success=%d price=%f token=%@",
                      MATToponAdapterLogPrefix, strongSelf, placementIdentifier, bidOk, bidResponse ? bidResponse.price : 0, bidResponse.bidToken ?: @"(nil)");
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
                    if (!strongSelfMain) return;
                    if (bidOk && bidResponse.bidToken.length > 0) {
                        strongSelfMain.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                        strongSelfMain.bidResponse = bidResponse;
                        [strongSelfMain.rewardedVideoAd loadAd:bidResponse.bidToken];
                    } else {
                        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeRewardVideo, @"bid request failed")];
                        [strongSelfMain.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"rewarded video")
                                                        adExtra:nil];
                    }
                });
            }];
        } else {
            [self->_rewardedVideoAd loadAd];
        }
        MaticooToponAdapterDebugLog(@"%@ rv loadADWithArgument MAIN_BLOCK_END adapter=%p placement=%@ rewardedVideoAd=%p delegate=%p",
              MATToponAdapterLogPrefix, self, placementIdentifier, self->_rewardedVideoAd, self->_delegate);
    });
}

- (void)didReceiveBidResult:(ATBidWinLossResult *)result {
    if (result.bidResultType == ATBidWinLossResultTypeWin) {
        NSString *winPrice = result.winPrice;
        if (winPrice == nil) {
            MATBiddingResponse *bidResponse = self.bidResponse;
            if (bidResponse) {
                winPrice = [NSString stringWithFormat:@"%f", bidResponse.price];
            }
        }
        
        MaticooToponAdapterDebugLog(@"%@ rv didReceiveBidResult WIN adapter=%p placement=%@ winPrice=%@ secondPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeRewardVideo, MATToponAdapterMediationSourceValue, winPrice ?: @"", result.secondPrice ?: @""];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_win" des:des];
        if (self.bidResponse) {
            [MATBiddingRequest reportTrack:self.bidResponse];
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

- (BOOL)adReadyRewardedWithInfo:(NSDictionary *)info {
    return self.rewardedVideoAd.isReady;
}

- (void)showRewardedVideoInViewController:(UIViewController *)viewController {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.rewardedVideoAd showAdFromViewController:viewController];
    });
}

- (void)dealloc {
    MaticooToponAdapterDebugLog(@"%@ rv MATRewardedVideoAdapter dealloc adapter=%p placementId=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, _placementId, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATToponAdapterEventDes(_placementId, MATToponAdapterAdTypeRewardVideo, nil)];
    _rewardedVideoAd.delegate = nil;
    _rewardedVideoAd = nil;
}

@end
