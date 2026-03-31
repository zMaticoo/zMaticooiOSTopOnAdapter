//
//  MATToponBaseAdapter.m
//  UnityFramework
//
//  Created by 韩腾 on 2026/3/12.
//

#import "MATToponBaseAdapter.h"
#import "MATToponSDKInitAdapter.h"

@implementation MATToponBaseAdapter

- (void)loadADWithArgument:(ATAdMediationArgument *)argument {
    NSLog(@"");
}

- (Class)initializeClassName {
    return MATToponSDKInitAdapter.class;
}

@end
