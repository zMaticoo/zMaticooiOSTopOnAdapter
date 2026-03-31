//
//  MATInterstitialAdapter.m
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import "MATInterstitialAdapter.h"
@import MaticooSDK;

static NSString * const kAdapterSource = @"top_on";
static const NSInteger kAdTypeInterstitial = 2;

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable msg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeInterstitial);
    dic[@"source"] = kAdapterSource;
    if (msg.length) {
        dic[@"msg"] = msg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

#pragma mark - Delegate

@interface MATInterstitialAdapterDelegate : NSObject <MATInterstitialAdDelegate>

@property (nonatomic, strong) ATInterstitialAdStatusBridge *adStatusBridge;
@property (nonatomic, copy) NSString *bidPriceStr;
@property (nonatomic, copy) NSString *placementId;

@end

@implementation MATInterstitialAdapterDelegate

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, nil)];

    [self.adStatusBridge atOnAdMetaLoadFinish:nil];
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    if (self.bidPriceStr.length) {
        extra[ATAdSendC2SBidPriceKey] = self.bidPriceStr;
        extra[ATAdSendC2SCurrencyTypeKey] = @(ATBiddingCurrencyTypeUS);
    }
    [self.adStatusBridge atOnInterstitialAdLoadedExtra:extra];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    [self.adStatusBridge atOnAdLoadFailed:error adExtra:nil];
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, nil)];
    [self.adStatusBridge atOnAdShow:nil];
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, nil)];
    [self.adStatusBridge atOnAdClick:nil];
}

- (void)interstitialAdDidClose:(MATInterstitialAd *)interstitialAd {
    [self.adStatusBridge atOnAdClosed:nil];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    [self.adStatusBridge atOnAdShowFailed:error extra:nil];
}

- (void)interstitialAdWillClose:(MATInterstitialAd *)interstitialAd {
    [self.adStatusBridge atOnAdWillClosed:nil];
}

- (void)interstitialAdDidSkip:(MATInterstitialAd *)interstitialAd {}
- (void)interstitialAdEndCardShow:(MATInterstitialAd *)interstitialAd {}

@end

#pragma mark - Adapter

@interface MATInterstitialAdapter () <ATBaseInterstitialAdapterProtocol>

@property (nonatomic, strong) MATInterstitialAdapterDelegate *delegate;
@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong) MATBiddingResponse *bidResponse;

@end

@implementation MATInterstitialAdapter

- (void)loadADWithArgument:(ATAdMediationArgument *)argument {
    [super loadADWithArgument:argument];

    NSString *placementIdentifier = argument.serverContentDic[@"placement_id"];
    if (!placementIdentifier.length) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, @"placement_id is empty")];
        [self.adStatusBridge atOnAdLoadFailed:[NSError errorWithDomain:ATADLoadingErrorDomain
                                                                  code:ATAdErrorCodeThirdPartySDKNotImportedProperly
                                                              userInfo:@{NSLocalizedDescriptionKey:@"AT has failed to load interstitial.",
                                                                         NSLocalizedFailureReasonErrorKey:@"placementid cannot be nil"}]
                                      adExtra:nil];
        return;
    }

    self.placementId = placementIdentifier;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementIdentifier, nil)];

    self.interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementIdentifier];
    self.delegate = [[MATInterstitialAdapterDelegate alloc] init];
    self.delegate.adStatusBridge = self.adStatusBridge;
    self.delegate.placementId = placementIdentifier;
    self.interstitial.delegate = self.delegate;

    NSLog(@"[MATInterstitialAdapter] serverContentDic = %@", argument.serverContentDic);
    ATUnitGroupModel *trackingInfoUnitGroupModel = argument.serverContentDic[@"tracking_info_unit_group_model"];;
    if (trackingInfoUnitGroupModel && trackingInfoUnitGroupModel.headerBidding) {
        MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
        param.placementId = placementIdentifier;
        param.adxId = @"topon_adapter_bidding";
        __weak __typeof__(self) weakSelf = self;
        [MATBiddingRequest biddingRequestWithParameter:param completion:^(MATBiddingResponse * _Nullable bidResponse) {
            __strong __typeof__(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (bidResponse.success) {
                strongSelf.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                strongSelf.bidResponse = bidResponse;
                [strongSelf.interstitial loadAd:bidResponse.bidToken];
            } else {
                [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, @"bid request failed")];
                [strongSelf.adStatusBridge atOnAdLoadFailed:[NSError errorWithDomain:ATADLoadingErrorDomain
                                                                                code:ATAdErrorCodeThirdPartySDKNotImportedProperly
                                                                            userInfo:@{NSLocalizedDescriptionKey:@"AT has failed to load interstitial.",
                                                                                       NSLocalizedFailureReasonErrorKey:@"bid token is failed"}]
                                                    adExtra:nil];
            }
        }];
    } else {
        [self.interstitial loadAd];
    }
}

- (void)didReceiveBidResult:(ATBidWinLossResult *)result {
    if (result.bidResultType == ATBidWinLossResultTypeWin) {
        NSLog(@"[MATInterstitialAdapter] bid win, winPrice=%@, secondPrice=%@", result.winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)kAdTypeInterstitial, kAdapterSource, result.winPrice ?: @"", result.secondPrice ?: @""];
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
        NSLog(@"[MATInterstitialAdapter] bid loss, lossReason=%ld, winPrice=%@", (long)result.lossReasonType, result.winPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"lossReason\":\"%@\"}",
                         self.placementId ?: @"", (long)kAdTypeInterstitial, kAdapterSource, result.winPrice ?: @"", lossReason];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
    }
}

- (void)showInterstitialInViewController:(UIViewController *)viewController {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(self.placementId, nil)];
    [self.interstitial showAdFromViewController:viewController];
}

- (BOOL)adReadyInterstitialWithInfo:(NSDictionary *)info {
    return self.interstitial.isReady;
}

- (void)dealloc {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(self.placementId, nil)];
}

@end
