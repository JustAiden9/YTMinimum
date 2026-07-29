#import <Foundation/Foundation.h>
#import "YTMCommon.h"

static BOOL YTMElementHasAdMetadata(id element) {
    id compatibility = YTMSafeValueForKey(element, @"compatibilityOptions");
    id adLoggingData = YTMSafeValueForKey(compatibility, @"hasAdLoggingData");
    return [adLoggingData respondsToSelector:@selector(boolValue)] && [adLoggingData boolValue];
}

static NSString *YTMElementDescription(id element) {
    NSString *description = [element description];
    return [description isKindOfClass:NSString.class] ? description.lowercaseString : @"";
}

static BOOL YTMElementDescriptionEqualsAny(NSString *description, NSArray<NSString *> *identifiers) {
    if (description.length == 0) return NO;
    return [identifiers containsObject:description];
}

// Element descriptions can include an entire nested feed tree. Never search those
// descriptions for broad words such as "post" or "horizontal": a single child
// match would suppress the parent renderer and leave an empty, full-height feed.
// YTLite avoids that failure by limiting this hook to exact renderer identifiers,
// with containsString used only for YouTube's established Shorts identifiers.
static BOOL YTMShouldHideNonAdFeedElement(id element) {
    NSString *description = YTMElementDescription(element);

    BOOL isSubscriptions = [YTMCurrentPivotIdentifier isEqualToString:@"FEsubscriptions"];
    BOOL preserveSubscriptionShorts = isSubscriptions && YTMBool(@"keepSubsShorts");
    if (YTMBool(@"hideShorts") && !preserveSubscriptionShorts &&
        ![description containsString:@"history*"]) {
        NSArray *shortsIdentifiers = @[
            @"shorts_shelf.eml",
            @"shorts_video_cell.eml",
            @"6shorts",
        ];
        for (NSString *identifier in shortsIdentifiers) {
            if ([description containsString:identifier]) return YES;
        }
    }

    NSDictionary<NSString *, NSArray<NSString *> *> *exactFilters = @{
        @"removeMoreTopics": @[@"more_topics", @"moretopics"],
        @"removeCommunityPosts": @[@"backstage_post", @"community_post", @"post_base_wrapper", @"post_root"],
        @"removeMixes": @[@"mix_card", @"mix_playlist", @"radio_playlist", @"radio_renderer"],
        @"removeLive": @[@"live_video"],
        @"removeHorizontalFeeds": @[@"horizontal_list", @"horizontal_shelf", @"horizontal_video_shelf"],
        @"removePlayables": @[@"game_card", @"mini_game", @"playables", @"playables_game"],
    };

    for (NSString *key in exactFilters) {
        if (YTMBool(key) && YTMElementDescriptionEqualsAny(description, exactFilters[key])) {
            return YES;
        }
    }

    return NO;
}

static NSURL *YTMFixedCoverURL(NSURL *originalURL) {
    if (!YTMBool(@"fixCovers") || !originalURL) return originalURL;

    NSDictionary<NSString *, NSString *> *replacementHosts = @{
        @"yt3.ggpht.com": @"yt4.ggpht.com",
        @"yt3.googleusercontent.com": @"yt4.googleusercontent.com",
    };
    NSString *replacement = replacementHosts[originalURL.host.lowercaseString];
    if (!replacement) return originalURL;

    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
    components.host = replacement;
    return components.URL ?: originalURL;
}

%group YTMFeedHooks

// Background playback and ad hooks originate from the MIT-licensed YTLite
// implementation and are intentionally kept small and version-gated here.
%hook YTIPlayerResponse
- (BOOL)isMonetized {
    return YTMBool(@"noAds") ? NO : %orig;
}
%end

%hook YTDataUtils
+ (id)spamSignalsDictionary {
    return YTMBool(@"noAds") ? nil : %orig;
}

+ (id)spamSignalsDictionaryWithoutIDFA {
    return YTMBool(@"noAds") ? nil : %orig;
}
%end

%hook YTAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context {
    if (!YTMBool(@"noAds")) %orig(context);
}
%end

%hook YTAccountScopedAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context {
    if (!YTMBool(@"noAds")) %orig(context);
}
%end

%hook YTIElementRenderer
- (NSData *)elementData {
    if (YTMBool(@"noAds") && YTMElementHasAdMetadata(self)) return nil;

    NSString *description = YTMElementDescription(self);
    NSArray *adRendererIdentifiers = @[
        @"brand_promo",
        @"product_carousel",
        @"product_engagement_panel",
        @"product_item",
        @"text_search_ad",
        @"text_image_button_layout",
        @"carousel_headered_layout",
        @"carousel_footered_layout",
        @"square_image_layout",
        @"landscape_image_wide_button_layout",
        @"feed_ad_metadata",
    ];
    if (YTMBool(@"noAds") && YTMElementDescriptionEqualsAny(description, adRendererIdentifiers)) {
        // Match YTLite's behavior: return valid empty data for these layout
        // renderers instead of removing a potentially shared parent renderer.
        return [NSData data];
    }

    if (YTMShouldHideNonAdFeedElement(self)) return nil;
    return %orig;
}
%end

%hook YTSectionListViewController
- (void)loadWithModel:(id)model {
    if (YTMBool(@"noAds")) {
        NSMutableArray *contents = YTMSafeValueForKey(model, @"contentsArray");
        if ([contents isKindOfClass:NSMutableArray.class]) {
            NSIndexSet *indexes = [contents indexesOfObjectsPassingTest:^BOOL(id supportedRenderer, NSUInteger index, BOOL *stop) {
                id section = YTMSafeValueForKey(supportedRenderer, @"itemSectionRenderer");
                NSArray *sectionContents = YTMSafeValueForKey(section, @"contentsArray");
                id first = [sectionContents isKindOfClass:NSArray.class] ? sectionContents.firstObject : nil;
                NSArray *promotedKeys = @[
                    @"hasPromotedVideoRenderer",
                    @"hasCompactPromotedVideoRenderer",
                    @"hasPromotedVideoInlineMutedRenderer",
                ];
                for (NSString *key in promotedKeys) {
                    id value = YTMSafeValueForKey(first, key);
                    if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) return YES;
                }
                return NO;
            }];
            [contents removeObjectsAtIndexes:indexes];
        }
    }
    %orig(model);
}
%end

%hook YTCommerceEventGroupHandler
- (void)addEventHandlers {
    if (!YTMBool(@"noAds")) %orig;
}
%end

%hook YTInterstitialPromoEventGroupHandler
- (void)addEventHandlers {
    if (!YTMBool(@"noAds")) %orig;
}
%end

%hook YTPromosheetEventGroupHandler
- (void)addEventHandlers {
    if (!YTMBool(@"noAds")) %orig;
}
%end

%hook YTPromoThrottleController
- (BOOL)canShowThrottledPromo {
    return YTMBool(@"noAds") ? NO : %orig;
}

- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)cap {
    return YTMBool(@"noAds") ? NO : %orig(cap);
}

- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)caps {
    return YTMBool(@"noAds") ? NO : %orig(caps);
}
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial {
    return YTMBool(@"noAds") ? YES : %orig;
}
%end

%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)renderer surveyParentResponder:(id)responder {
    if (!YTMBool(@"noAds")) %orig(renderer, responder);
}
%end

%hook YTImageSelectionStrategyImageURLs
- (id)initWithSelectedImageURL:(NSURL *)selectedImageURL updatedImageURL:(NSURL *)updatedImageURL {
    return %orig(YTMFixedCoverURL(selectedImageURL), YTMFixedCoverURL(updatedImageURL));
}
%end

%end

%ctor {
    if (YTMIsSupportedYouTubeVersion()) {
        %init(YTMFeedHooks);
    }
}
