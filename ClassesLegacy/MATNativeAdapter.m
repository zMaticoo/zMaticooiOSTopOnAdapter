//
//  MATNativeAdapter.m
//  MaticooToponAdapterLegacy
//
//  AnyThinkiOS ≤ 6.4.92：loadADWithInfo + ATNativeADCustomEvent + ATNativeRenderer + C2S。
//  CustomEvent strong→Ad；不用 protectLifeCycleObject，避免与 adapter.customEvent 形成环。
//

#import "MATNativeAdapter.h"
#import "MATToponSDKInitAdapter.h"
#import "MATToponLegacyBidCache.h"
#import "MATToponLegacyInitHelper.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;
@import AnyThinkSDK;
@import AnyThinkNative;

static NSString * const kUseImageSelfRenderKey = @"use_image_self_render";

#pragma mark - CustomEvent

@interface MATNativeCustomEvent : ATNativeADCustomEvent <MATNativeAdDelegate, MATVideoLifecycleDelegate>
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL useImageSelfRender;
@property (nonatomic, strong, nullable) MATNativeAd *maticooAd;
@property (nonatomic, strong, nullable) MATMediaView *mediaView;
@property (nonatomic, strong, nullable) MATAdChoicesView *adChoicesView;
- (void)maticoo_destroyNativeAd;
@end

@implementation MATNativeCustomEvent

- (void)maticoo_destroyNativeAd {
    MATNativeAd *ad = self.maticooAd;
    self.maticooAd = nil;
    self.mediaView = nil;
    self.adChoicesView = nil;
    if (!ad) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [ad destroy];
    });
}

- (NSDictionary *)buildAssetsWithNativeAd:(MATNativeAd *)nativeAd {
    MATNativeAdElements *e = nativeAd.nativeElements;
    NSMutableDictionary *asset = [NSMutableDictionary dictionary];
    asset[kATAdAssetsCustomEventKey] = self;
    asset[kATAdAssetsCustomObjectKey] = nativeAd;
    asset[kATNativeADAssetsUnitIDKey] = self.placementId ?: @"";
    asset[kATNativeADAssetsIsExpressAdKey] = @NO;

    if (e.headline.length > 0) {
        asset[kATNativeADAssetsMainTitleKey] = e.headline;
    }
    if (e.body.length > 0) {
        asset[kATNativeADAssetsMainTextKey] = e.body;
    }
    if (e.callToAction.length > 0) {
        asset[kATNativeADAssetsCTATextKey] = e.callToAction;
    }
    if (e.advertiser.length > 0) {
        asset[kATNativeADAssetsAdvertiserKey] = e.advertiser;
    }
    if (e.icon.image) {
        asset[kATNativeADAssetsIconImageKey] = e.icon.image;
    }
    NSString *iconURL = e.icon.imageURL.absoluteString;
    if (iconURL.length > 0) {
        asset[kATNativeADAssetsIconURLKey] = iconURL;
    }

    NSArray<MATAdImage *> *images = e.images;
    if (images.count == 1) {
        MATAdImage *img = images.firstObject;
        if (img.image) {
            asset[kATNativeADAssetsMainImageKey] = img.image;
        }
        NSString *url = img.imageURL.absoluteString;
        if (url.length > 0) {
            asset[kATNativeADAssetsImageURLKey] = url;
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
            asset[kATNativeADAssetsImageListKey] = [urlList copy];
        } else if (images.firstObject.image) {
            asset[kATNativeADAssetsMainImageKey] = images.firstObject.image;
        }
    }

    MATMediaView *mediaView = nil;
    BOOL containsVideo = NO;
    if (e.mediaContent.hasVideoContent) {
        containsVideo = YES;
        asset[kATNativeADAssetsVideoDurationKey] = @((NSInteger)e.mediaContent.duration);
        if (e.mediaContent.aspectRatio > 0) {
            asset[kATNativeADAssetsVideoAspectRatioKey] = @(e.mediaContent.aspectRatio);
        }
        mediaView = [[MATMediaView alloc] init];
        mediaView.clipsToBounds = YES;
    } else if (self.useImageSelfRender) {
        containsVideo = NO;
        if (e.mediaContent.aspectRatio > 0) {
            asset[kATNativeADAssetsVideoAspectRatioKey] = @(e.mediaContent.aspectRatio);
        }
    } else {
        // 与 Latest 一致：非 self-render 图片也走 MediaView 容器
        containsVideo = YES;
        mediaView = [[MATMediaView alloc] init];
        mediaView.clipsToBounds = YES;
    }
    asset[kATNativeADAssetsContainsVideoFlag] = @(containsVideo);
    if (mediaView) {
        self.mediaView = mediaView;
        asset[kATNativeADAssetsMediaViewKey] = mediaView;
    }

    MATAdChoicesView *adChoicesView = [[MATAdChoicesView alloc] init];
    [adChoicesView setNativeAd:nativeAd];
    self.adChoicesView = adChoicesView;
    asset[kATNativeADAssetsLogoViewKey] = adChoicesView;

    MATVideoController *vc = e.mediaContent.videoController;
    if (vc) {
        vc.delegate = self;
    }
    return [asset copy];
}

- (void)nativeAdLoadSuccess:(MATNativeAd *)nativeAd {
    MaticooToponAdapterDebugLog(@"%@ native didLoad placement=%@", MATToponAdapterLogPrefix, self.placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, nil)];
    if (self.customEventMetaDataDidLoadedBlock) {
        self.customEventMetaDataDidLoadedBlock();
    }
    NSDictionary *asset = [self buildAssetsWithNativeAd:nativeAd];
    [self trackNativeAdLoaded:@[asset]];
}

- (void)nativeAdFailed:(MATNativeAd *)nativeAd withError:(NSError *)error {
    (void)nativeAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, error.localizedDescription)];
    [self trackNativeAdLoadFailed:error];
    [self maticoo_destroyNativeAd];
}

- (void)nativeAdDisplayed:(MATNativeAd *)nativeAd {
    (void)nativeAd;
    MaticooToponAdapterDebugLog(@"%@ native impression placement=%@", MATToponAdapterLogPrefix, self.placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, nil)];
    [self trackNativeAdImpression];
}

- (void)nativeAd:(MATNativeAd *)nativeAd displayFailWithError:(NSError *)error {
    (void)nativeAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, error.localizedDescription)];
    [self maticoo_destroyNativeAd];
}

- (void)nativeAdClicked:(MATNativeAd *)nativeAd {
    (void)nativeAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeNative, nil)];
    [self trackNativeAdClick];
}

#pragma mark - MATVideoLifecycleDelegate

- (void)videoDidStart {
    [self trackNativeAdVideoStart];
}

- (void)videoDidPlay {}
- (void)videoDidPause {}

- (void)videoDidEnd {
    [self trackNativeAdVideoEnd];
}

- (void)videoDidMute:(BOOL)isMuted {
    (void)isMuted;
}

- (void)dealloc {
    NSString *placementId = _placementId;
    MATNativeAd *ad = _maticooAd;
    _maticooAd = nil;
    _mediaView = nil;
    _adChoicesView = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
    MaticooToponAdapterDebugLog(@"%@ native customEvent dealloc placement=%@", MATToponAdapterLogPrefix, placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                       des:MATToponAdapterEventDes(placementId, MATToponAdapterAdTypeNative, nil)];
}

@end

#pragma mark - Renderer

@interface MATNativeRenderer : ATNativeRenderer
@end

@implementation MATNativeRenderer

/// ADView.nativeAd 在正常链路是 ATNativeADCache；类型不符时勿直接访问 .assets（会 unrecognized selector）。
- (ATNativeADCache *)maticoo_nativeCache {
    id nativeAd = self.ADView.nativeAd;
    if ([nativeAd isKindOfClass:[ATNativeADCache class]]) {
        return (ATNativeADCache *)nativeAd;
    }
    return nil;
}

- (void)bindCustomEvent {
    ATNativeADCache *cache = [self maticoo_nativeCache];
    if (!cache) {
        return;
    }
    MATNativeCustomEvent *customEvent = cache.assets[kATAdAssetsCustomEventKey];
    if (![customEvent isKindOfClass:[MATNativeCustomEvent class]]) {
        return;
    }
    customEvent.adView = self.ADView;
    self.ADView.customEvent = customEvent;
}

- (__kindof UIView *)createMediaView {
    ATNativeADCache *cache = [self maticoo_nativeCache];
    UIView *mediaView = cache.assets[kATNativeADAssetsMediaViewKey];
    if ([mediaView isKindOfClass:[UIView class]]) {
        return mediaView;
    }
    return [[MATMediaView alloc] init];
}

- (void)renderOffer:(ATNativeADCache *)offer {
    [super renderOffer:offer];
    [self bindCustomEvent];

    NSDictionary *assets = [offer isKindOfClass:[ATNativeADCache class]] ? offer.assets : nil;
    MATNativeAd *nativeAd = assets[kATAdAssetsCustomObjectKey];
    if (![nativeAd isKindOfClass:[MATNativeAd class]]) {
        return;
    }

    MATMediaView *mediaView = nil;
    id mv = assets[kATNativeADAssetsMediaViewKey];
    if ([mv isKindOfClass:[MATMediaView class]]) {
        mediaView = (MATMediaView *)mv;
    }

    UIView *container = self.ADView.selfRenderView ?: self.ADView;
    NSArray<UIView *> *clickables = [self.ADView clickableViews];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATToponAdapterEventDes(nativeAd.placementID, MATToponAdapterAdTypeNative, nil)];
    [nativeAd registerViewForInteraction:container
                               mediaView:mediaView
                          clickableViews:clickables];
}

- (BOOL)isVideoContents {
    ATNativeADCache *cache = [self maticoo_nativeCache];
    return [cache.assets[kATNativeADAssetsContainsVideoFlag] boolValue];
}

- (void)destroyNative {
    ATNativeADCache *cache = [self maticoo_nativeCache];
    MATNativeCustomEvent *customEvent = cache.assets[kATAdAssetsCustomEventKey];
    if ([customEvent isKindOfClass:[MATNativeCustomEvent class]]) {
        [customEvent maticoo_destroyNativeAd];
        return;
    }
    MATNativeAd *nativeAd = cache.assets[kATAdAssetsCustomObjectKey];
    if (![nativeAd isKindOfClass:[MATNativeAd class]]) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [nativeAd destroy];
    });
}

- (ATNativeAdType)getNativeAdType {
    return ATNativeAdTypeFeed;
}

- (ATNativeAdRenderType)getCurrentNativeAdRenderType {
    return ATNativeAdRenderSelfRender;
}

@end

#pragma mark - Adapter

// TopOn 通过 +rendererClass / loadADWithInfo: 运行时识别 ATNativeAdapter；不显式声明协议以免属性冲突。
@interface MATNativeAdapter () <ATAdAdapter> {
    void (^_metaDataDidLoadedBlock)(void);
}
/// 仅 load 阶段由 adapter 抓住；load 成功后 TopOn 持有 customEvent，adapter 可提前释放。
@property (nonatomic, strong) MATNativeCustomEvent *customEvent;
@end

@implementation MATNativeAdapter

@synthesize metaDataDidLoadedBlock = _metaDataDidLoadedBlock;

+ (Class)rendererClass {
    return [MATNativeRenderer class];
}

- (void)setMetaDataDidLoadedBlock:(void (^)(void))metaDataDidLoadedBlock {
    _metaDataDidLoadedBlock = [metaDataDidLoadedBlock copy];
    // 桥到 CustomEvent，避免依赖 adapter 保活
    if (self.customEvent) {
        self.customEvent.customEventMetaDataDidLoadedBlock = _metaDataDidLoadedBlock;
    }
}

- (void (^)(void))metaDataDidLoadedBlock {
    return _metaDataDidLoadedBlock;
}

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
    NSDictionary *safeLocalInfo = [localInfo isKindOfClass:[NSDictionary class]] ? localInfo : nil;
    BOOL useImageSelfRender = NO;
    id useImageSelfRenderObj = safeLocalInfo[kUseImageSelfRenderKey];
    if ([useImageSelfRenderObj isKindOfClass:[NSNumber class]]) {
        useImageSelfRender = [(NSNumber *)useImageSelfRenderObj boolValue];
    }

    NSString *placementIdentifier = serverInfo[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                           des:MATToponAdapterEventDes(@"", MATToponAdapterAdTypeNative, @"placement_id is empty")];
        if (completion) {
            completion(@[], MATToponAdapterErrorInvalidPlacement(@"native"));
        }
        return;
    }

    MATNativeCustomEvent *customEvent = [[MATNativeCustomEvent alloc] initWithInfo:serverInfo localInfo:localInfo];
    customEvent.placementId = placementIdentifier;
    customEvent.useImageSelfRender = useImageSelfRender;
    customEvent.requestCompletionBlock = completion;
    if (_metaDataDidLoadedBlock) {
        customEvent.customEventMetaDataDidLoadedBlock = _metaDataDidLoadedBlock;
    }
    self.customEvent = customEvent;

    ATUnitGroupModel *unitGroup = serverInfo[kATAdapterCustomInfoUnitGroupModelKey];
    NSString *bidId = serverInfo[kATAdapterCustomInfoBuyeruIdKey];
    NSString *cacheKey = unitGroup.unitID.length > 0 ? unitGroup.unitID : placementIdentifier;

    MaticooToponAdapterDebugLog(@"%@ native loadAD placement=%@ bidId=%@ unitID=%@ useImageSelfRender=%d",
          MATToponAdapterLogPrefix, placementIdentifier, bidId, cacheKey, useImageSelfRender);

    __weak __typeof__(self) weakSelf = self;
    [MATToponLegacyInitHelper ensureInitializedWithServerInfo:serverInfo completion:^(NSError *error) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        MATNativeCustomEvent *event = strongSelf.customEvent ?: customEvent;
        if (error) {
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeNative, error.localizedDescription)];
            [event trackNativeAdLoadFailed:error];
            strongSelf.customEvent = nil;
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
            MATNativeCustomEvent *eventMain = strongSelfMain.customEvent ?: customEvent;
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                               des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeNative, nil)];

            MATNativeAd *ad = [[MATNativeAd alloc] initWithPlacementID:placementIdentifier];
            ad.delegate = eventMain;
            eventMain.maticooAd = ad;

            if ([bidId isKindOfClass:[NSString class]] && bidId.length > 0) {
                MATBiddingResponse *bidResponse = [MATToponLegacyBidCache bidResponseForKey:cacheKey];
                [MATToponLegacyBidCache removeBidResponseForKey:cacheKey];
                if (bidResponse.bidToken.length > 0) {
                    [MATToponLegacyBidCache attachBidResponse:bidResponse toAdObject:ad];
                    [ad loadAd:bidResponse.bidToken];
                } else {
                    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                                       des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeNative, @"bid request failed")];
                    [eventMain trackNativeAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"native")];
                    [eventMain maticoo_destroyNativeAd];
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
    if (![customObject isKindOfClass:[MATNativeAd class]]) {
        return NO;
    }
    return [(MATNativeAd *)customObject nativeElements] != nil;
}

+ (BOOL)isSupportAdType:(ATUnitGroupModel *)unitGroupModel {
    (void)unitGroupModel;
    return YES;
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
            completion(nil, MATToponAdapterErrorInvalidPlacement(@"native"));
        }
        return;
    }

    NSString *cacheKey = unitGroupModel.unitID.length > 0 ? unitGroupModel.unitID : placementIdentifier;
    MaticooToponAdapterDebugLog(@"%@ native bidRequest zmaticooPid=%@ toponPid=%@ unitID=%@",
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
                    completion(nil, bidResponse.error ?: MATToponAdapterErrorBiddingFailed(@"native"));
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
                                                           des:MATToponAdapterEventDes(nil, MATToponAdapterAdTypeNative, nil)];
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
                     (long)MATToponAdapterAdTypeNative, MATToponAdapterMediationSourceValue, price ?: @"", lossReason];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
}

@end
