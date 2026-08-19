//
//  MATBannerAdapter.m
//  AnyThinkSDKDemo
//
//  Created by root on 2023/9/20.
//  Copyright © 2023 root. All rights reserved.
//

#import "MATBannerAdapter.h"
#import "MaticooToponAdapterDebugLog.h"
@import MaticooSDK;

@interface MATBannerAdapterDelegate : NSObject <MATBannerAdDelegate>
@property (strong, nonatomic) ATBannerAdStatusBridge *adStatusBridge;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, copy) NSString *bidPriceStr;
@end

@implementation MATBannerAdapterDelegate
- (void)bannerAdDidLoad:(MATBannerAd *)nativeBannerAd{
    MaticooToponAdapterDebugLog(@"%@ banner delegate=bannerAdDidLoad delegateSelf=%p placement=%@ banner=%p thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, nativeBannerAd, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, nil)];
    [self.adStatusBridge atOnAdMetaLoadFinish:nil];
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    if (self.bidPriceStr.length) {
        extra[ATAdSendC2SBidPriceKey] = self.bidPriceStr;
        extra[ATAdSendC2SCurrencyTypeKey] = @(ATBiddingCurrencyTypeUS);
    }
    [self.adStatusBridge atOnBannerAdLoadedWithView:nativeBannerAd adExtra:[extra copy]];
}

- (void)bannerAd:(nonnull MATBannerAd *)nativeBannerAd didFailWithError:(nonnull NSError *)error {
    MaticooToponAdapterDebugLog(@"%@ banner delegate=didFailWithError delegateSelf=%p placement=%@ banner=%p err=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, nativeBannerAd, error, [NSThread currentThread], [NSThread isMainThread]);
    NSString *msg = error ? error.localizedDescription : @"";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, msg)];
    [self.adStatusBridge atOnAdLoadFailed:error adExtra:nil];
}

- (void)bannerAdDidClick:(nonnull MATBannerAd *)banner {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, nil)];
    [self.adStatusBridge atOnAdClick:nil];
}

- (void)bannerAdDidImpression:(nonnull MATBannerAd *)banner {
    MaticooToponAdapterDebugLog(@"%@ banner delegate=bannerAdDidImpression delegateSelf=%p placement=%@ banner=%p thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, self.placementId, banner, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, nil)];
    [self.adStatusBridge atOnAdShow:nil];
}

- (void)bannerAdDismissed:(nonnull MATBannerAd *)bannerAd{
    [self.adStatusBridge atOnAdClosed:nil];
}

- (void)bannerAd:(nonnull MATBannerAd *)bannerAd showFailWithError:(nonnull NSError *)error {
    NSString *msg = error ? error.localizedDescription : @"";
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATToponAdapterEventDes(self.placementId, MATToponAdapterAdTypeBanner, msg)];
    [self.adStatusBridge atOnAdShowFailed:error extra:nil];
}


@end

@interface MATBannerAdapter()<ATBaseBannerAdapterProtocol>
@property (nonatomic, readonly) MATBannerAdapterDelegate *delegate;
@property(nonatomic, strong) MATBannerAd *bannerAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, strong) MATBiddingResponse *bidResponse;
@end

@implementation MATBannerAdapter

// 广告对象在主线程 load 写，TopOn 可能在其它线程读 dealloc / HB 回调后再 load。
// bidResponse 在主线程的 bidding completion 里写，TopOn 在自己的线程读 -didReceiveBidResult:。
// ARC 并发读写 strong 属性会读到哨兵指针 0x400000000000bad0，读写必须同锁。
// 持锁只保护指针交换；拿到局部变量后再调 SDK，不要在 @synchronized(self) 内调外部方法。
@synthesize bannerAd = _bannerAd;
@synthesize bidResponse = _bidResponse;

- (MATBannerAd *)bannerAd {
    @synchronized (self) {
        return _bannerAd;
    }
}

- (void)setBannerAd:(MATBannerAd *)bannerAd {
    @synchronized (self) {
        _bannerAd = bannerAd;
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
    MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument ENTRY adapter=%p thread=%@ main=%d placement_id(raw)=%@ cls=%@ serverKeys=%@",
          MATToponAdapterLogPrefix,
          self,
          [NSThread currentThread],
          [NSThread isMainThread],
          rawPlacement,
          rawPlacement ? NSStringFromClass([rawPlacement class]) : @"(nil)",
          argument.serverContentDic ? [[argument.serverContentDic allKeys] componentsJoinedByString:@","] : @"(nil)");
    [super loadADWithArgument:argument];
    // localInfoDic 理论上应是 NSDictionary，但若 TopOn 内部或测试桩塞了非字典实例，下标访问会崩溃，先做类型校验。
    NSDictionary *localInfo = [argument.localInfoDic isKindOfClass:[NSDictionary class]] ? argument.localInfoDic : nil;
    id sizeValue = localInfo[kATAdLoadingExtraBannerAdSizeKey];
    CGSize adSize = [sizeValue respondsToSelector:@selector(CGSizeValue)] ? [sizeValue CGSizeValue] : CGSizeMake(320.0f, 50.0f);
    NSString *placementIdentifier = argument.serverContentDic[@"placement_id"];
    if (![placementIdentifier isKindOfClass:[NSString class]] || placementIdentifier.length == 0) {
        MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument FAIL_EMPTY_PLACEMENT adapter=%p", MATToponAdapterLogPrefix, self);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(@"", MATToponAdapterAdTypeBanner, @"placement_id is empty")];
        [self.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorInvalidPlacement(@"banner") adExtra:nil];
        return;
    }
    self.placementId = placementIdentifier;
    MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument DISPATCH_MAIN adapter=%p placement=%@ adSize={%.0f,%.0f}", MATToponAdapterLogPrefix, self, placementIdentifier, adSize.width, adSize.height);
    dispatch_async(dispatch_get_main_queue(), ^{
        MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument MAIN_BLOCK_BEGIN adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeBanner, nil)];
        MATBannerAd *bannerAd = [[MATBannerAd alloc] initWithPlacementID:placementIdentifier];
        self->_delegate = [[MATBannerAdapterDelegate alloc] init];
        self->_delegate.adStatusBridge = self.adStatusBridge;
        self->_delegate.placementId = placementIdentifier;
        bannerAd.delegate = self->_delegate;
        NSMutableDictionary *extra = [NSMutableDictionary dictionary];
        if (localInfo != nil && localInfo.count > 0) {
            [extra addEntriesFromDictionary:[self ensureParams:localInfo]];
        }
        extra[@"source"] = MATToponAdapterMediationSourceValue;
        [bannerAd setLocalExtra:[extra copy]];
        id canCloseObj = localInfo[@"can_close_ad"];
        if ([canCloseObj isKindOfClass:[NSNumber class]]) {
            bannerAd.canCloseAd = [(NSNumber *)canCloseObj boolValue];
        } else if ([canCloseObj isKindOfClass:[NSString class]]) {
            bannerAd.canCloseAd = [(NSString *)canCloseObj boolValue];
        }
        // localExtra 经 ensureParams 后只剩 NSString 值，这里再把原始 localInfo 整体传一次，避免丢失非字符串值。
        NSDictionary *extraMap = MATToponAdapterLoadExtraMapFromLocalInfo(localInfo);
        bannerAd.frame = CGRectMake(0, 0, adSize.width, adSize.height);
        self.bannerAd = bannerAd;
        id rawTrackingInfo = argument.serverContentDic[@"tracking_info_unit_group_model"];
        ATUnitGroupModel *trackingInfoUnitGroupModel =
            [rawTrackingInfo isKindOfClass:[ATUnitGroupModel class]] ? rawTrackingInfo : nil;
        if (trackingInfoUnitGroupModel && trackingInfoUnitGroupModel.headerBidding) {
            MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument HB_BIDDING_REQUEST adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
            MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
            param.placementId = placementIdentifier;
            param.adxId = @"topon_adapter_bidding";
            __weak __typeof__(self) weakSelf = self;
            [MATBiddingRequest biddingRequestWithParameter:param extra:extraMap completion:^(MATBiddingResponse * _Nullable bidResponse) {
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                BOOL bidOk = (bidResponse != nil && bidResponse.success);
                NSString *tokenLog = bidResponse ? (bidResponse.biddingRequestId ?: @"") : @"(nil)";
                MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument HB_BIDDING_RESPONSE adapter=%p placement=%@ success=%d price=%f token=%@",
                      MATToponAdapterLogPrefix, strongSelf, placementIdentifier, bidOk, bidResponse ? bidResponse.price : 0, tokenLog);
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
                    if (!strongSelfMain) return;
                    if (bidOk) {
                        strongSelfMain.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                        strongSelfMain.bidResponse = bidResponse;
                        [strongSelfMain.bannerAd loadAd:bidResponse.biddingRequestId extraMap:extraMap];
                    } else {
                        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeBanner, @"bid request failed")];
                        [strongSelfMain.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"banner")
                                                            adExtra:nil];
                    }
                });
            }];
        } else {
            [bannerAd loadAdExtraMap:extraMap];
        }
        MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument MAIN_BLOCK_END adapter=%p placement=%@ bannerAd=%p delegate=%p",
              MATToponAdapterLogPrefix, self, placementIdentifier, bannerAd, self->_delegate);
    });
}

- (void)didReceiveBidResult:(ATBidWinLossResult *)result {
    if (result.bidResultType == ATBidWinLossResultTypeWin) {
        MATBiddingResponse *bidResponse = self.bidResponse;
        NSString *winPrice = result.winPrice;
        if (winPrice == nil && bidResponse) {
            winPrice = [NSString stringWithFormat:@"%f", bidResponse.price];
        }
        MaticooToponAdapterDebugLog(@"%@ banner didReceiveBidResult WIN adapter=%p placement=%@ winPrice=%@ secondPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeBanner, MATToponAdapterMediationSourceValue, winPrice ?: @"", result.secondPrice ?: @""];
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
        MaticooToponAdapterDebugLog(@"%@ banner didReceiveBidResult LOSS adapter=%p placement=%@ lossReason=%ld winPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, (long)result.lossReasonType, result.winPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"lossReason\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeBanner, MATToponAdapterMediationSourceValue, result.winPrice ?: @"", lossReason];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_bid_loss" des:des];
    }
}

- (NSDictionary *)ensureParams:(NSDictionary *)dict{
    NSMutableDictionary * newDict = [NSMutableDictionary dictionary];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return newDict;
    }

    @try {
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]]) {
                [newDict setValue:obj forKey:key];
            }
        }];
    }@catch (NSException *exception) {
        
    } @finally {
        
    }
    
    return newDict;
}

- (void)dealloc {
    MaticooToponAdapterDebugLog(@"%@ banner MATBannerAdapter dealloc adapter=%p placementId=%@ thread=%@ main=%d",
          MATToponAdapterLogPrefix, self, _placementId, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATToponAdapterEventDes(_placementId, MATToponAdapterAdTypeBanner, nil)];
    MATBannerAd *ad = nil;
    @synchronized (self) {
        ad = _bannerAd;
        _bannerAd = nil;
    }
    ad.delegate = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}


@end
