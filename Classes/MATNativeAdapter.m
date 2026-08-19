//
//  MATNativeAdapter.m
//  MaticooToponAdapter
//
//  TopOn Native adapter for Maticoo Native ad.
//  - 接 ATBaseMediationAdapter（继承自 MATToponBaseAdapter）
//  - load 成功后构建一个 ATCustomNetworkNativeAd 列表回调给 TopOn 的 ATNativeAdStatusBridge
//

#import "MATNativeAdapter.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;
#import <AnyThinkSDK/ATBaseAdapterProtocol.h>
#import <AnyThinkSDK/ATCustomNetworkNativeAd.h>
#import <AnyThinkSDK/ATAdEnums.h>
#import <AnyThinkSDK/ATAdStatusBridge.h>

static NSString * const kUseImageSelfRenderKey = @"use_image_self_render";

#pragma mark - Wrap Maticoo MATNativeAdElements 为 TopOn ATCustomNetworkNativeAd

@interface MATToponNativeAdWrapper : ATCustomNetworkNativeAd
@property (nonatomic, strong) MATNativeAd *maticooAd;
@end

@implementation MATToponNativeAdWrapper

// maticooAd 在 SDK 回调线程写（nativeAdLoadSuccess:），而 TopOn 会在主线程 render 时调
// -registerClickableViews:... 、在自己的线程调 -destroyNative。ARC 并发读写 strong 属性会读到
// 哨兵指针 0x400000000000bad0，读写必须同锁。
@synthesize maticooAd = _maticooAd;

- (MATNativeAd *)maticooAd {
    @synchronized (self) {
        return _maticooAd;
    }
}

- (void)setMaticooAd:(MATNativeAd *)maticooAd {
    @synchronized (self) {
        _maticooAd = maticooAd;
    }
}

- (void)destroyNative {
    // 取出并清空放在同一个临界区里，保证多线程重复调用时只会 destroy 一次。
    MATNativeAd *ad = nil;
    @synchronized (self) {
        ad = _maticooAd;
        _maticooAd = nil;
    }
    [ad destroy];
}

- (void)registerClickableViews:(NSArray<UIView *> *)clickableViews
                  withContainer:(UIView *)container
               registerArgument:(ATNativeRegisterArgument *)registerArgument {
    (void)registerArgument;
    MATNativeAd *ad = self.maticooAd;
    if (!ad || !container) return;
    MATMediaView *mediaView = nil;
    if ([self.mediaView isKindOfClass:[MATMediaView class]]) {
        mediaView = (MATMediaView *)self.mediaView;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATToponAdapterEventDes(ad.placementID, MATToponAdapterAdTypeNative, nil)];
    [ad registerViewForInteraction:container
                         mediaView:mediaView
                    clickableViews:clickableViews];
}

- (BOOL)isExpressAd {
    return NO;
}

@end

#pragma mark - Delegate

@interface MATNativeAdapterDelegate : NSObject <MATNativeAdDelegate, MATVideoLifecycleDelegate>
@property (nonatomic, strong) ATNativeAdStatusBridge *adStatusBridge;
@property (nonatomic, copy)   NSString *placementId;
@property (nonatomic, copy)   NSString *bidPriceStr;
@property (nonatomic, weak)   MATToponNativeAdWrapper *wrapper;
@property (nonatomic, assign) BOOL useImageSelfRender;
@end

@implementation MATNativeAdapterDelegate

- (void)nativeAdLoadSuccess:(MATNativeAd *)nativeAd {
    MaticooToponAdapterDebugLog(@"%@ native delegate=nativeAdLoadSuccess delegateSelf=%p placement=%@ nativeAd=%p thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, nativeAd, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, nil)];
    MATNativeAdElements *e = nativeAd.nativeElements;
    MATToponNativeAdWrapper *wrap = [[MATToponNativeAdWrapper alloc] init];
    wrap.maticooAd = nativeAd;
    wrap.title = e.headline ?: @"";
    wrap.mainText = e.body ?: @"";
    wrap.ctaText = e.callToAction ?: @"";
    wrap.advertiser = e.advertiser;
    wrap.icon = e.icon.image;
    wrap.iconUrl = e.icon.imageURL.absoluteString;

    NSArray<MATAdImage *> *images = e.images;
    if (images.count == 1) {
        MATAdImage *img = images.firstObject;
        wrap.mainImage = img.image;
        NSString *url = img.imageURL.absoluteString;
        if (url.length > 0) {
            wrap.imageUrl = url;
        }
    } else if (images.count > 1) {
        NSMutableArray<NSString *> *urlList = [NSMutableArray array];
        for (MATAdImage *img in images) {
            NSString *url = img.imageURL.absoluteString;
            if (url.length > 0) {
                [urlList addObject:url];
            }
        }
        if (urlList.count > 0) {
            wrap.imageList = [urlList copy];
        } else {
            // 多图仅有本地 UIImage、无 URL 时，TopOn imageList 无法承载，回退首张 mainImage
            MATAdImage *first = images.firstObject;
            wrap.mainImage = first.image;
        }
    }
    MATMediaView *mediaView = nil;
    if (e.mediaContent.hasVideoContent) {
        wrap.isVideoContents = YES;
        wrap.videoDuration = e.mediaContent.duration;
        if (e.mediaContent.aspectRatio > 0) {
            wrap.videoAspectRatio = e.mediaContent.aspectRatio;
        }
        mediaView = [[MATMediaView alloc] init];
        mediaView.clipsToBounds = YES;
    } else if (self.useImageSelfRender) {
        wrap.isVideoContents = NO;
        if (e.mediaContent.aspectRatio > 0) {
            wrap.videoAspectRatio = e.mediaContent.aspectRatio;
        }
    } else {
        wrap.isVideoContents = YES;
        wrap.videoAspectRatio = 0;
        mediaView = [[MATMediaView alloc] init];
        mediaView.clipsToBounds = YES;
    }
    
    MATAdChoicesView *adChoicesView = [[MATAdChoicesView alloc] init];
    [adChoicesView setNativeAd:nativeAd];
    wrap.logoView = adChoicesView;
    
    wrap.mediaView = mediaView;
    wrap.nativeAdRenderType = ATNativeAdRenderSelfRender;
    
    self.wrapper = wrap;

    MATVideoController *vc = nativeAd.nativeElements.mediaContent.videoController;
    if (vc) {
        vc.delegate = self;
    }

    [self.adStatusBridge atOnAdMetaLoadFinish:nil];
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    if (self.bidPriceStr.length) {
        extra[ATAdSendC2SBidPriceKey] = self.bidPriceStr;
        extra[ATAdSendC2SCurrencyTypeKey] = @(ATBiddingCurrencyTypeUS);
    }
    [self.adStatusBridge atOnNativeAdLoadedArray:@[wrap] adExtra:[extra copy]];
}

- (void)nativeAdFailed:(MATNativeAd *)nativeAd withError:(NSError *)error {
    MaticooToponAdapterDebugLog(@"%@ native delegate=nativeAdFailed delegateSelf=%p placement=%@ nativeAd=%p err=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, nativeAd, error, [NSThread currentThread], [NSThread isMainThread]);
    NSString *msg = error.localizedDescription ?: @"";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, msg)];
    [self.adStatusBridge atOnAdLoadFailed:error adExtra:nil];
}

- (void)nativeAdDisplayed:(MATNativeAd *)nativeAd {
    MaticooToponAdapterDebugLog(@"%@ native delegate=nativeAdDisplayed delegateSelf=%p placement=%@ nativeAd=%p thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, nativeAd, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, nil)];
    [self.adStatusBridge atOnAdShow:nil];
}

- (void)nativeAd:(MATNativeAd *)nativeAd displayFailWithError:(NSError *)error {
    MaticooToponAdapterDebugLog(@"%@ native delegate=displayFailWithError delegateSelf=%p placement=%@ nativeAd=%p error=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, nativeAd, error, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, error.localizedDescription)];
    [self.adStatusBridge atOnAdShowFailed:error extra:nil];
}

- (void)nativeAdClicked:(MATNativeAd *)nativeAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, nil)];
    [self.adStatusBridge atOnAdClick:nil];
}

#pragma mark - MATVideoLifecycleDelegate

- (void)videoDidStart {
    MaticooToponAdapterDebugLog(@"%@ native videoDidStart delegateSelf=%p placement=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, [NSThread currentThread], [NSThread isMainThread]);
    [self.adStatusBridge atOnAdVideoStart:nil];
}

- (void)videoDidPlay {
    MaticooToponAdapterDebugLog(@"%@ native videoDidPlay delegateSelf=%p placement=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, [NSThread currentThread], [NSThread isMainThread]);
}

- (void)videoDidPause {
    MaticooToponAdapterDebugLog(@"%@ native videoDidPause delegateSelf=%p placement=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, [NSThread currentThread], [NSThread isMainThread]);
}

- (void)videoDidEnd {
    MaticooToponAdapterDebugLog(@"%@ native videoDidEnd delegateSelf=%p placement=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, [NSThread currentThread], [NSThread isMainThread]);
    [self.adStatusBridge atOnAdVideoEnd:nil];
}

- (void)videoDidMute:(BOOL)isMuted {
    MaticooToponAdapterDebugLog(@"%@ native videoDidMute delegateSelf=%p placement=%@ isMuted=%d thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, isMuted, [NSThread currentThread], [NSThread isMainThread]);
}

@end

#pragma mark - MATNativeAdapter

@interface MATNativeAdapter () <ATBaseNativeAdapterProtocol>
@property (nonatomic, strong) MATNativeAd *maticooAd;
@property (nonatomic, strong) MATNativeAdapterDelegate *delegate;
@property (nonatomic, copy)   NSString *placementId;
@property (nonatomic, strong) MATBiddingResponse *bidResponse;
@end

@implementation MATNativeAdapter

// 广告对象在主线程 load 写，TopOn 可能在其它线程 dealloc。
// bidResponse 在主线程的 bidding completion 里写，TopOn 在自己的线程读 -didReceiveBidResult:。
// ARC 并发读写 strong 属性会读到哨兵指针 0x400000000000bad0，读写必须同锁。
// 持锁只保护指针交换；拿到局部变量后再调 SDK，不要在 @synchronized(self) 内调外部方法。
@synthesize maticooAd = _maticooAd;
@synthesize bidResponse = _bidResponse;

- (MATNativeAd *)maticooAd {
    @synchronized (self) {
        return _maticooAd;
    }
}

- (void)setMaticooAd:(MATNativeAd *)maticooAd {
    @synchronized (self) {
        _maticooAd = maticooAd;
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
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                           des:MATToponAdapterEventDes(@"", MATToponAdapterAdTypeNative, @"placement_id is empty")];
        [self.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorInvalidPlacement(@"native")
                                       adExtra:nil];
        return;
    }
    self.placementId = placementIdentifier;
    MaticooToponAdapterDebugLog(@"%@ native loadADWithArgument entry adapter=%p argument=%p placement=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, argument, placementIdentifier, [NSThread currentThread], [NSThread isMainThread]);
    NSDictionary *localInfo = [argument.localInfoDic isKindOfClass:[NSDictionary class]] ? argument.localInfoDic : nil;
    NSNumber *isMuted = MATToponAdapterIsMutedFromLocalInfo(localInfo);
    BOOL useImageSelfRender = NO;
    if (localInfo) {
        id useImageSelfRenderObj = localInfo[kUseImageSelfRenderKey];
        if ([useImageSelfRenderObj isKindOfClass:[NSNumber class]]) {
            useImageSelfRender = [(NSNumber *)useImageSelfRenderObj boolValue];
        }
    }
    id rawTrackingInfo = argument.serverContentDic[@"tracking_info_unit_group_model"];
    ATUnitGroupModel *trackingInfo = [rawTrackingInfo isKindOfClass:[ATUnitGroupModel class]] ? rawTrackingInfo : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        MaticooToponAdapterDebugLog(@"%@ native loadADWithArgument MAIN_BLOCK_START adapter=%p placement=%@ bid=%d useImageSelfRender=%d",
              MATToponAdapterLogPrefix, self, placementIdentifier, (trackingInfo && trackingInfo.headerBidding), useImageSelfRender);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                           des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeNative, nil)];
        self.maticooAd = [[MATNativeAd alloc] initWithPlacementID:placementIdentifier];
        self.delegate = [[MATNativeAdapterDelegate alloc] init];
        self.delegate.adStatusBridge = (ATNativeAdStatusBridge *)self.adStatusBridge;
        self.delegate.placementId = placementIdentifier;
        self.delegate.useImageSelfRender = useImageSelfRender;
        self.maticooAd.delegate = self.delegate;
        if (isMuted != nil) {
            MATVideoOptions *videoOpts = [[MATVideoOptions alloc] init];
            videoOpts.startMuted = isMuted.boolValue;
            MATNativeAdOptions *nativeOpts = [[MATNativeAdOptions alloc] init];
            nativeOpts.videoOptions = videoOpts;
            [self.maticooAd setNativeAdOptions:nativeOpts];
        }
        NSDictionary *extraMap = MATToponAdapterNativeLoadExtraMapFromLocalInfo(localInfo);
        if (trackingInfo && trackingInfo.headerBidding) {
            MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
            param.placementId = placementIdentifier;
            param.adxId = @"topon_adapter_bidding";
            __weak __typeof__(self) weakSelf = self;
            [MATBiddingRequest biddingRequestWithParameter:param extra:extraMap completion:^(MATBiddingResponse * _Nullable bidResponse) {
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (bidResponse.success && bidResponse.biddingRequestId) {
                        strongSelf.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                        strongSelf.bidResponse = bidResponse;
                        [strongSelf.maticooAd loadAd:bidResponse.biddingRequestId extraMap:extraMap];
                        MaticooToponAdapterDebugLog(@"%@ native loadADWithArgument BIDDING_SUCCESS adapter=%p placement=%@ token=%@ price=%f",
                              MATToponAdapterLogPrefix, strongSelf, placementIdentifier, bidResponse.biddingRequestId, bidResponse.price);
                    } else {
                        MaticooToponAdapterDebugLog(@"%@ native loadADWithArgument BIDDING_FAILED adapter=%p placement=%@",
                              MATToponAdapterLogPrefix, strongSelf, placementIdentifier);
                        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                                           des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeNative, @"bid request failed")];
                        [strongSelf.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"native")
                                                        adExtra:nil];
                    }
                });
            }];
        } else {
            [self.maticooAd loadAdExtraMap:extraMap];
        }
        MaticooToponAdapterDebugLog(@"%@ native loadADWithArgument MAIN_BLOCK_END adapter=%p placement=%@ nativeAd=%p delegate=%p",
              MATToponAdapterLogPrefix, self, placementIdentifier, self.maticooAd, self.delegate);
    });
}

- (void)didReceiveBidResult:(ATBidWinLossResult *)result {
    if (result.bidResultType == ATBidWinLossResultTypeWin) {
        MATBiddingResponse *bidResponse = self.bidResponse;
        NSString *winPrice = result.winPrice;
        if (winPrice == nil && bidResponse) {
            winPrice = [NSString stringWithFormat:@"%f", bidResponse.price];
        }
        MaticooToponAdapterDebugLog(@"%@ native didReceiveBidResult WIN adapter=%p placement=%@ winPrice=%@ secondPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeNative, MATToponAdapterMediationSourceValue, winPrice ?: @"", result.secondPrice ?: @""];
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
        MaticooToponAdapterDebugLog(@"%@ native didReceiveBidResult LOSS adapter=%p placement=%@ lossReason=%ld winPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, (long)result.lossReasonType, result.winPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"lossReason\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeNative, MATToponAdapterMediationSourceValue, result.winPrice ?: @"", lossReason];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
    }
}

- (void)dealloc {
    MaticooToponAdapterDebugLog(@"%@ native MATNativeAdapter dealloc adapter=%p placementId=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, _placementId, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                       des:MATToponAdapterEventDes(_placementId, MATToponAdapterAdTypeNative, nil)];
    MATNativeAd *ad = nil;
    @synchronized (self) {
        ad = _maticooAd;
        _maticooAd = nil;
    }
    ad.delegate = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}

@end
