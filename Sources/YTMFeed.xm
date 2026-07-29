#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "YTMCommon.h"
#import "YTMYouTube.h"

#pragma mark - Ad helpers

static BOOL YTMElementHasAdMetadata(id element) {
    id compatibility = YTMSafeValueForKey(element, @"compatibilityOptions");
    id adLoggingData = YTMSafeValueForKey(compatibility, @"hasAdLoggingData");
    return [adLoggingData respondsToSelector:@selector(boolValue)] && [adLoggingData boolValue];
}

static BOOL YTMDescriptionEqualsAny(NSString *description, NSArray<NSString *> *identifiers) {
    if (description.length == 0) return NO;
    return [identifiers containsObject:description];
}

#pragma mark - Feed element hiding
//
// Feed items are hidden by collapsing the cell that carries them, never by
// refusing to return element data. Returning nil from -elementData leaves the
// collection view holding a cell it cannot measure, which is what produced the
// full-screen empty gaps that only filled in after scrolling.

static NSDictionary<NSString *, NSArray<NSString *> *> *YTMHiddenIdentifierTokens(void) {
    static NSDictionary<NSString *, NSArray<NSString *> *> *tokens;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tokens = @{
            @"hideShorts": @[
                @"shorts-shelf",
                @"shorts_shelf",
                @"shorts-grid",
                @"shorts_grid",
                @"shorts-lockup",
                @"shorts_lockup",
                @"shorts_video_cell",
                @"shorts-video-cell",
                @"reel_shelf",
                @"reel-shelf",
            ],
            @"removeHorizontalFeeds": @[
                @"horizontal_card_list",
                @"horizontal-card-list",
                @"horizontal_video_shelf",
                @"horizontal-video-shelf",
                @"horizontal_list",
                @"continue_watching",
            ],
            @"removeCommunityPosts": @[
                @"post_base_wrapper",
                @"post-base-wrapper",
                @"backstage_post",
                @"backstage-post",
                @"community_post",
                @"post_shelf",
            ],
            @"removeMixes": @[
                @"mix_lockup",
                @"mix-lockup",
                @"mix_shelf",
                @"radio_lockup",
                @"radio-lockup",
                @"compact_radio",
            ],
            @"removeMoreTopics": @[
                @"more_topics",
                @"more-topics",
                @"topics_shelf",
                @"topic_shelf",
            ],
            @"removePlayables": @[
                @"playables",
                @"game_card",
                @"mini_game",
            ],
            @"removePromoBanners": @[
                @"statement_banner",
                @"statement-banner",
                @"premium_promo",
                @"mealbar_promo",
            ],
        };
    });
    return tokens;
}

static BOOL YTMFeedFilteringEnabled(void) {
    for (NSString *key in YTMHiddenIdentifierTokens()) {
        if (!YTMBool(key)) continue;
        if ([key isEqualToString:@"hideShorts"] &&
            YTMBool(@"keepSubsShorts") &&
            YTMCurrentPivotIsSubscriptions()) {
            continue;
        }
        return YES;
    }
    return NO;
}

static BOOL YTMIdentifierIsHidden(NSString *identifier) {
    if (identifier.length == 0) return NO;
    NSString *lowercase = identifier.lowercaseString;

    BOOL inSubscriptions = YTMCurrentPivotIsSubscriptions();
    NSDictionary<NSString *, NSArray<NSString *> *> *tokens = YTMHiddenIdentifierTokens();

    for (NSString *key in tokens) {
        if (!YTMBool(key)) continue;
        if ([key isEqualToString:@"hideShorts"] && inSubscriptions && YTMBool(@"keepSubsShorts")) continue;

        for (NSString *token in tokens[key]) {
            if ([lowercase containsString:token]) return YES;
        }
    }
    return NO;
}

static NSString *YTMTemplateURIForNode(ASDisplayNode *node) {
    id controller = [node respondsToSelector:@selector(controller)] ? [node controller] : nil;
    if (![controller respondsToSelector:@selector(owningComponent)]) return nil;

    ELMComponent *component = [(ELMNodeController *)controller owningComponent];
    if (![component respondsToSelector:@selector(templateURI)]) return nil;

    NSString *templateURI = [component templateURI];
    return [templateURI isKindOfClass:NSString.class] ? templateURI : nil;
}

static NSString *YTMAccessibilityIdentifierForNode(ASDisplayNode *node) {
    if (![node respondsToSelector:@selector(accessibilityIdentifier)]) return nil;
    NSString *identifier = node.accessibilityIdentifier;
    return [identifier isKindOfClass:NSString.class] ? identifier : nil;
}

// The identifiers we care about sit on the cell node itself or one or two levels
// under it, so the walk is deliberately shallow. Deep traversal on every sizing
// pass is expensive and risks matching an unrelated descendant.
static BOOL YTMNodeTreeIsHidden(ASDisplayNode *node, NSUInteger depth) {
    if (![node isKindOfClass:%c(ASDisplayNode)]) return NO;
    if (YTMIdentifierIsHidden(YTMAccessibilityIdentifierForNode(node))) return YES;
    if (YTMIdentifierIsHidden(YTMTemplateURIForNode(node))) return YES;
    if (depth == 0) return NO;

    NSArray *children = [node respondsToSelector:@selector(yogaChildren)] ? node.yogaChildren : nil;
    if (![children isKindOfClass:NSArray.class]) return NO;

    NSUInteger inspected = 0;
    for (ASDisplayNode *child in children) {
        if (++inspected > 12) break;
        if (YTMNodeTreeIsHidden(child, depth - 1)) return YES;
    }
    return NO;
}

static const void *YTMNodeHiddenAssociation = &YTMNodeHiddenAssociation;

static BOOL YTMShouldHideCellNode(ASDisplayNode *node) {
    if (![node isKindOfClass:%c(ASDisplayNode)]) return NO;

    // Sizing is queried repeatedly for the same node while scrolling, so the
    // verdict is cached per node. The settings generation is folded into the
    // cached value so a toggle change invalidates every earlier verdict.
    uint64_t generation = YTMSettingsGeneration();
    NSNumber *cached = objc_getAssociatedObject(node, YTMNodeHiddenAssociation);
    if (cached && cached.unsignedLongLongValue >> 1 == generation) {
        return (cached.unsignedLongLongValue & 1) != 0;
    }

    BOOL hidden = YTMFeedFilteringEnabled() && YTMNodeTreeIsHidden(node, 2);
    objc_setAssociatedObject(node,
                             YTMNodeHiddenAssociation,
                             @((generation << 1) | (hidden ? 1 : 0)),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return hidden;
}

#pragma mark - Cover art

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
    if (!YTMBool(@"noAds")) return %orig;

    if (YTMElementHasAdMetadata(self)) return nil;

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
    if (YTMDescriptionEqualsAny([(id)self description], adRendererIdentifiers)) {
        // Valid but empty data collapses the ad layout without discarding a
        // renderer the surrounding feed may still reference.
        return [NSData data];
    }

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

// Collapsing and removing feed cells is grouped separately so each hook can be
// skipped when the host build does not expose the method it needs.
%group YTMFeedSizingHooks

// Collapse the cell that carries hidden content so the feed closes the gap
// instead of leaving an unmeasurable placeholder behind.
%hook ASCollectionView
- (CGSize)sizeForElement:(ASCollectionElement *)element {
    if ([element respondsToSelector:@selector(node)] && YTMShouldHideCellNode([element node])) {
        return CGSizeZero;
    }
    return %orig;
}
%end

%end

%group YTMFeedCellHooks

// Legacy shelves are plain cells rather than element nodes, so their height does
// not come from -sizeForElement: and the cell has to be removed outright, the way
// YTLite does it. Element-backed cells are left to the sizing hook because
// deleting rows while the collection view is asking for them is far riskier.
%hook YTAsyncCollectionView
- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;
    if (!cell) return cell;

    BOOL shouldRemove = NO;
    BOOL keepSubscriptionShorts = YTMBool(@"keepSubsShorts") && YTMCurrentPivotIsSubscriptions();

    if (YTMBool(@"hideShorts") && !keepSubscriptionShorts &&
        [cell isKindOfClass:objc_lookUpClass("YTReelShelfCell")]) {
        shouldRemove = YES;
    } else if (YTMBool(@"removeHorizontalFeeds") &&
               [cell isKindOfClass:objc_lookUpClass("YTHorizontalCardListCell")]) {
        shouldRemove = YES;
    }

    if (shouldRemove &&
        indexPath.section < [self numberOfSections] &&
        indexPath.item < [self numberOfItemsInSection:indexPath.section]) {
        [self deleteItemsAtIndexPaths:@[indexPath]];
    }
    return cell;
}
%end

%end

%ctor {
    if (!YTMIsSupportedYouTubeVersion()) return;

    %init(YTMFeedHooks);

    // Hooking a selector the host build does not implement would leave %orig
    // pointing at nothing, so the layout group is gated on the real methods.
    if (class_getInstanceMethod(objc_lookUpClass("ASCollectionView"), @selector(sizeForElement:))) {
        %init(YTMFeedSizingHooks);
    }
    if (objc_lookUpClass("YTAsyncCollectionView")) {
        %init(YTMFeedCellHooks);
    }
}
