#import "YTMCommon.h"
#import <stdatomic.h>

NSString *const YTMDefaultsSuite = @"com.aiden.ytminimum";
NSString *const YTMSupportedYouTubeVersion = @"21.30.5";
static atomic_bool YTMPivotIsSubscriptions = false;

void YTMSetCurrentPivotIdentifier(NSString *identifier) {
    atomic_store(&YTMPivotIsSubscriptions, [identifier isEqualToString:@"FEsubscriptions"]);
}

BOOL YTMCurrentPivotIsSubscriptions(void) {
    return atomic_load(&YTMPivotIsSubscriptions);
}

static atomic_ullong YTMGeneration = 1;

static NSDictionary *YTMRegisteredDefaults(void) {
    return @{
        // Feed. Options that depend on YouTube's own layout identifiers start
        // disabled: identifiers change between releases, so they are opt-in.
        @"noAds": @YES,
        @"hideShorts": @YES,
        @"keepSubsShorts": @NO,
        @"removeMoreTopics": @NO,
        @"removeCommunityPosts": @NO,
        @"removeMixes": @NO,
        @"removeHorizontalFeeds": @NO,
        @"removePlayables": @NO,
        @"removePromoBanners": @YES,
        @"fixCovers": @YES,

        // Player.
        @"progressBarStyle": @1,
        @"mainColor": @"#FF0000",
        @"gradientColor": @"#FF0000",
        @"scrubberColor": @"#FF0000",
        @"playbackRateIndex": @3,
        @"backgroundPlayback": @YES,
        @"miniplayer": @NO,
        @"disableAutoplay": @NO,
        @"noContentWarning": @NO,
        @"noHints": @NO,
        @"autoFullscreen": @NO,
        @"exitFullscreen": @NO,
        @"leftGesture": @0,
        @"rightGesture": @0,

        // Tab bar.
        @"startupPivot": @"FEwhat_to_watch",
        @"translucentTabBar": @NO,
        @"removeLabels": @NO,
        @"removeIndicators": @NO,
        @"activeTabs": YTMDefaultActiveTabs(),
        @"inactiveTabs": YTMDefaultInactiveTabs(),
    };
}

NSUserDefaults *YTMDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaults = [[NSUserDefaults alloc] initWithSuiteName:YTMDefaultsSuite];
        [defaults registerDefaults:YTMRegisteredDefaults()];
    });
    return defaults;
}

uint64_t YTMSettingsGeneration(void) {
    return atomic_load(&YTMGeneration);
}

static void YTMSettingsDidChange(void) {
    atomic_fetch_add(&YTMGeneration, 1);
}

BOOL YTMBool(NSString *key) {
    return [YTMDefaults() boolForKey:key];
}

NSInteger YTMInteger(NSString *key) {
    return [YTMDefaults() integerForKey:key];
}

NSString *YTMString(NSString *key) {
    id value = [YTMDefaults() objectForKey:key];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

NSArray<NSString *> *YTMStringArray(NSString *key) {
    id value = [YTMDefaults() objectForKey:key];
    if (![value isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (id item in value) {
        if ([item isKindOfClass:NSString.class]) [strings addObject:item];
    }
    return strings.copy;
}

void YTMSetBool(NSString *key, BOOL value) {
    [YTMDefaults() setBool:value forKey:key];
    YTMSettingsDidChange();
}

void YTMSetInteger(NSString *key, NSInteger value) {
    [YTMDefaults() setInteger:value forKey:key];
    YTMSettingsDidChange();
}

void YTMSetObject(NSString *key, id value) {
    if (value) {
        [YTMDefaults() setObject:value forKey:key];
    } else {
        [YTMDefaults() removeObjectForKey:key];
    }
    YTMSettingsDidChange();
}

void YTMResetSettings(void) {
    NSUserDefaults *defaults = YTMDefaults();
    for (NSString *key in YTMRegisteredDefaults()) {
        [defaults removeObjectForKey:key];
    }
    YTMSettingsDidChange();
}

static UIColor *YTMColorFromHexString(NSString *hex) {
    NSString *clean = [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if (clean.length != 6 && clean.length != 8) return UIColor.systemRedColor;

    unsigned long long value = 0;
    [[NSScanner scannerWithString:clean] scanHexLongLong:&value];
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha = 1.0;

    if (clean.length == 8) {
        red = ((value >> 24) & 0xFF) / 255.0;
        green = ((value >> 16) & 0xFF) / 255.0;
        blue = ((value >> 8) & 0xFF) / 255.0;
        alpha = (value & 0xFF) / 255.0;
    } else {
        red = ((value >> 16) & 0xFF) / 255.0;
        green = ((value >> 8) & 0xFF) / 255.0;
        blue = (value & 0xFF) / 255.0;
    }

    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

UIColor *YTMColor(NSString *key) {
    return YTMColorFromHexString(YTMString(key));
}

NSString *YTMHexStringFromColor(UIColor *color) {
    UIColor *rgbColor = [color resolvedColorWithTraitCollection:UITraitCollection.currentTraitCollection];
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 1;
    if (![rgbColor getRed:&red green:&green blue:&blue alpha:&alpha]) return @"#FF0000";
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
            lround(red * 255.0), lround(green * 255.0), lround(blue * 255.0)];
}

NSString *YTMInstalledYouTubeVersion(void) {
    NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    return [version isKindOfClass:NSString.class] ? version : @"";
}

// YTMinimum is built against YTMSupportedYouTubeVersion, but refusing to load on
// every other build would silently disable the tweak after a YouTube update and
// leave the settings toggles doing nothing. Anything from the same major release
// is accepted; the exact pairing is reported in the settings page instead.
BOOL YTMIsSupportedYouTubeVersion(void) {
    NSString *installed = YTMInstalledYouTubeVersion();
    if (installed.length == 0) return NO;
    if ([installed isEqualToString:YTMSupportedYouTubeVersion]) return YES;

    NSString *installedMajor = [installed componentsSeparatedByString:@"."].firstObject;
    NSString *supportedMajor = [YTMSupportedYouTubeVersion componentsSeparatedByString:@"."].firstObject;
    return installedMajor.length > 0 && [installedMajor isEqualToString:supportedMajor];
}

id YTMSafeValueForKey(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

BOOL YTMDescriptionContainsAny(id object, NSArray<NSString *> *tokens) {
    NSString *description = [[object description] lowercaseString];
    for (NSString *token in tokens) {
        if ([description containsString:token.lowercaseString]) return YES;
    }
    return NO;
}

NSArray<NSString *> *YTMDefaultActiveTabs(void) {
    return @[
        @"FEwhat_to_watch",
        @"FEexplore",
        @"FEuploads",
        @"FEsubscriptions",
        @"FElibrary",
    ];
}

NSArray<NSString *> *YTMDefaultInactiveTabs(void) {
    return @[
        @"FEshorts",
        @"FEhistory",
        @"FEpost_home",
        @"VLWL",
    ];
}

NSString *YTMTitleForPivotIdentifier(NSString *identifier) {
    static NSDictionary<NSString *, NSString *> *titles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        titles = @{
            @"FEwhat_to_watch": @"Home",
            @"FEexplore": @"Explore",
            @"FEuploads": @"Create",
            @"FEsubscriptions": @"Subscriptions",
            @"FElibrary": @"Library",
            @"FEshorts": @"Shorts",
            @"FEhistory": @"History",
            @"FEpost_home": @"Posts",
            @"VLWL": @"Watch Later",
        };
    });
    return titles[identifier] ?: identifier;
}

