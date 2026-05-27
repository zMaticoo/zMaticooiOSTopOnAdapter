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
        self->_bannerAd = [[MATBannerAd alloc] initWithPlacementID:placementIdentifier];
        self->_delegate = [[MATBannerAdapterDelegate alloc] init];
        self->_delegate.adStatusBridge = self.adStatusBridge;
        self->_delegate.placementId = placementIdentifier;
        self->_bannerAd.delegate = self->_delegate;
        NSMutableDictionary *extra = [NSMutableDictionary dictionary];
        if (localInfo != nil && localInfo.count > 0) {
            [extra addEntriesFromDictionary:[self ensureParams:localInfo]];
        }
        extra[@"source"] = MATToponAdapterMediationSourceValue;
        [(MATBannerAd *)self->_bannerAd setLocalExtra:[extra copy]];
        id canCloseObj = localInfo[@"can_close_ad"];
        if ([canCloseObj isKindOfClass:[NSNumber class]]) {
            ((MATBannerAd *)self->_bannerAd).canCloseAd = [(NSNumber *)canCloseObj boolValue];
        } else if ([canCloseObj isKindOfClass:[NSString class]]) {
            ((MATBannerAd *)self->_bannerAd).canCloseAd = [(NSString *)canCloseObj boolValue];
        }
        self->_bannerAd.frame = CGRectMake(0, 0, adSize.width, adSize.height);
        id rawTrackingInfo = argument.serverContentDic[@"tracking_info_unit_group_model"];
        ATUnitGroupModel *trackingInfoUnitGroupModel =
            [rawTrackingInfo isKindOfClass:[ATUnitGroupModel class]] ? rawTrackingInfo : nil;
        if (trackingInfoUnitGroupModel && trackingInfoUnitGroupModel.headerBidding) {
            MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument HB_BIDDING_REQUEST adapter=%p placement=%@", MATToponAdapterLogPrefix, self, placementIdentifier);
            MATBiddingRequestParameter *param = [[MATBiddingRequestParameter alloc] init];
            param.placementId = placementIdentifier;
            param.adxId = @"topon_adapter_bidding";
            __weak __typeof__(self) weakSelf = self;
            [MATBiddingRequest biddingRequestWithParameter:param completion:^(MATBiddingResponse * _Nullable bidResponse) {
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                BOOL bidOk = (bidResponse != nil && bidResponse.success);
                NSString *tokenLog = bidResponse ? (bidResponse.bidToken ?: @"") : @"(nil)";
                MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument HB_BIDDING_RESPONSE adapter=%p placement=%@ success=%d price=%f token=%@",
                      MATToponAdapterLogPrefix, strongSelf, placementIdentifier, bidOk, bidResponse ? bidResponse.price : 0, tokenLog);
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof__(weakSelf) strongSelfMain = weakSelf;
                    if (!strongSelfMain) return;
                    if (bidOk) {
                        strongSelfMain.delegate.bidPriceStr = [NSString stringWithFormat:@"%f", bidResponse.price];
                        strongSelfMain.bidResponse = bidResponse;
                        [strongSelfMain.bannerAd loadAd:bidResponse.bidToken];
                    } else {
                        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATToponAdapterEventDes(placementIdentifier, MATToponAdapterAdTypeBanner, @"bid request failed")];
                        [strongSelfMain.adStatusBridge atOnAdLoadFailed:MATToponAdapterErrorBiddingFailed(@"banner")
                                                            adExtra:nil];
                    }
                });
            }];
        } else {
            [self->_bannerAd loadAd];
        }
        MaticooToponAdapterDebugLog(@"%@ banner loadADWithArgument MAIN_BLOCK_END adapter=%p placement=%@ bannerAd=%p delegate=%p",
              MATToponAdapterLogPrefix, self, placementIdentifier, self->_bannerAd, self->_delegate);
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
        MaticooToponAdapterDebugLog(@"%@ banner didReceiveBidResult WIN adapter=%p placement=%@ winPrice=%@ secondPrice=%@",
              MATToponAdapterLogPrefix, self, self.placementId, winPrice, result.secondPrice);
        NSString *des = [NSString stringWithFormat:@"{\"placementId\":\"%@\",\"adType\":%ld,\"source\":\"%@\",\"winPrice\":\"%@\",\"secondPrice\":\"%@\"}",
                         self.placementId ?: @"", (long)MATToponAdapterAdTypeBanner, MATToponAdapterMediationSourceValue, winPrice ?: @"", result.secondPrice ?: @""];
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
    MATBannerAd *ad = _bannerAd;
    _bannerAd.delegate = nil;
    _bannerAd = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}


@end
