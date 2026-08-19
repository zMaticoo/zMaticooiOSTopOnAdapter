//
//  MATInterstitialAdapter.m
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import "MATInterstitialAdapter.h"
@import MaticooSDK;
#import "MaticooToponAdapterDebugLog.h"

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
/// 本次 load 成功的广告标识，show 时回传给 SDK 以展示同一个 offer。
@property (nonatomic, strong, nullable) MATMaticooIds *maticooIds;

@end

@implementation MATInterstitialAdapterDelegate

// maticooIds 在 SDK 回调线程写、在 TopOn 线程经 -adReadyInterstitialWithInfo: 读，读写必须同锁。
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

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd maticooIds:(MATMaticooIds *)maticooIds {
    self.maticooIds = maticooIds;
    [self mat_handleDidLoad];
}

// 旧回调仅在 SDK 未走新回调时兜底，这里屏蔽废弃实现告警
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd {
    [self mat_handleDidLoad];
}
#pragma clang diagnostic pop

- (void)mat_handleDidLoad {
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

// 广告对象与 delegate 在主线程写，而 TopOn 会在自己的线程轮询 -adReadyInterstitialWithInfo:。
// bidResponse 同理：bidding completion 在主线程写，TopOn 在自己的线程读 -didReceiveBidResult:。
// ARC 并发读写 strong 属性会读到哨兵指针 0x400000000000bad0，读写必须同锁。
@synthesize interstitial = _interstitial;
@synthesize delegate = _delegate;
@synthesize bidResponse = _bidResponse;

- (MATInterstitialAd *)interstitial {
    @synchronized (self) {
        return _interstitial;
    }
}

- (void)setInterstitial:(MATInterstitialAd *)interstitial {
    @synchronized (self) {
        _interstitial = interstitial;
    }
}

- (MATInterstitialAdapterDelegate *)delegate {
    @synchronized (self) {
        return _delegate;
    }
}

- (void)setDelegate:(MATInterstitialAdapterDelegate *)delegate {
    @synchronized (self) {
        _delegate = delegate;
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
    [super loadADWithArgument:argument];

    NSString *placementIdentifier = argument.serverContentDic[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(nil, @"placement_id is empty")];
        [self.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorInvalidPlacement(@"interstitial")
                                      adExtra:nil];
        return;
    }

    self.placementId = placementIdentifier;
    MaticooToponAdapterDebugLog(@"[MATInterstitialAdapter] serverContentDic = %@", argument.serverContentDic);
    NSDictionary *extraMap = MATToponAdapterLoadExtraMapFromLocalInfo(argument.localInfoDic);
    NSNumber *isMuted = MATToponAdapterIsMutedFromLocalInfo(argument.localInfoDic);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementIdentifier, nil)];

        MATInterstitialAd *interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementIdentifier];
        MATInterstitialAdapterDelegate *adDelegate = [[MATInterstitialAdapterDelegate alloc] init];
        adDelegate.adStatusBridge = self.adStatusBridge;
        adDelegate.placementId = placementIdentifier;
        interstitial.delegate = adDelegate;
        if (isMuted != nil) {
            interstitial.videoMute = isMuted.boolValue;
        }
        self.delegate = adDelegate;
        self.interstitial = interstitial;

        id rawTrackingInfo = argument.serverContentDic[@"tracking_info_unit_group_model"];
        ATUnitGroupModel *trackingInfoUnitGroupModel =
            [rawTrackingInfo isKindOfClass:[ATUnitGroupModel class]] ? rawTrackingInfo : nil;
        if (trackingInfoUnitGroupModel && trackingInfoUnitGroupModel.headerBidding) {
            MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
            param.placementId = placementIdentifier;
            param.adxId = @"topon_adapter_bidding";
            __weak __typeof__(self) weakSelf = self;
            [MATBiddingRequest biddingRequestWithParameter:param extra:extraMap completion:^(MATBiddingResponse * _Nullable bidResponse) {
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                BOOL bidOk = (bidResponse != nil && bidResponse.success);
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
                    if (!strongSelfMain) return;
                    if (bidOk && bidResponse.biddingRequestId.length > 0) {
                        strongSelfMain.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                        strongSelfMain.bidResponse = bidResponse;
                        [strongSelfMain.interstitial loadAd:bidResponse.biddingRequestId extraMap:extraMap];
                    } else {
                        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, @"bid request failed")];
                        [strongSelfMain.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"interstitial")
                                                            adExtra:nil];
                    }
                });
            }];
        } else {
            [interstitial loadAdExtraMap:extraMap];
        }
    });
}

- (void)didReceiveBidResult:(ATBidWinLossResult *)result {
    if (result.bidResultType == ATBidWinLossResultTypeWin) {
        MATBiddingResponse *bidResponse = self.bidResponse;
        NSString *winPrice = result.winPrice;
        if (winPrice == nil && bidResponse) {
            winPrice = [NSString stringWithFormat:@"%f", bidResponse.price];
        }
        
        MaticooToponAdapterDebugLog(@"[MATInterstitialAdapter] bid win, winPrice=%@, secondPrice=%@", winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)kAdTypeInterstitial, kAdapterSource, winPrice ?: @"", result.secondPrice ?: @""];
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
        MaticooToponAdapterDebugLog(@"[MATInterstitialAdapter] bid loss, lossReason=%ld, winPrice=%@", (long)result.lossReasonType, result.winPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"lossReason\":\"%@\"}",
                         self.placementId ?: @"", (long)kAdTypeInterstitial, kAdapterSource, result.winPrice ?: @"", lossReason];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
    }
}

- (void)showInterstitialInViewController:(UIViewController *)viewController {
    MATToponAdapterApplyGDPRFromTopOn();
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(self.placementId, nil)];
    MATInterstitialAd *interstitial = self.interstitial;
    MATMaticooIds *maticooIds = self.delegate.maticooIds;
    [interstitial showAdFromViewController:viewController maticooIds:maticooIds];
}

/// 按本 adapter 实例持有的 offer 判定，与 `showInterstitialInViewController:` 传的是同一个 Ids。
/// 不能用不带参数的 `isReady`：同一 pid 下多个 offer 共用一个 MATInterstitialAd，
/// 它只要队列里还有任意一条可展示就为 YES，会让 TopOn 把已展示/已过期的 offer 当成可用，
/// 随后 show 必然回 30114/30101。
- (BOOL)adReadyInterstitialWithInfo:(NSDictionary *)info {
    MATInterstitialAd *interstitial = self.interstitial;
    MATMaticooIds *maticooIds = self.delegate.maticooIds;
    return [interstitial isReadyWithMaticooIds:maticooIds];
}

- (void)dealloc {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(_placementId, nil)];
    MATInterstitialAd *ad = nil;
    @synchronized (self) {
        ad = _interstitial;
        _interstitial = nil;
    }
    ad.delegate = nil;
}

@end
