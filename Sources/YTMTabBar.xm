#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "YTMCommon.h"

@interface YTPivotBarView : UIView
@end

@interface YTPivotBarViewController : UIViewController
@end

static NSString *YTMPivotIdentifierForSupportedRenderer(id supportedRenderer) {
    id item = YTMSafeValueForKey(supportedRenderer, @"pivotBarItemRenderer");
    NSString *identifier = YTMSafeValueForKey(item, @"pivotIdentifier");
    if (identifier.length > 0) return identifier;

    id iconOnlyItem = YTMSafeValueForKey(supportedRenderer, @"pivotBarIconOnlyItemRenderer");
    identifier = YTMSafeValueForKey(iconOnlyItem, @"pivotIdentifier");
    return identifier;
}

static NSInteger YTMIconTypeForPivotIdentifier(NSString *identifier) {
    NSDictionary<NSString *, NSNumber *> *iconTypes = @{
        @"FEexplore": @292,
        @"FEhistory": @225,
        @"FEpost_home": @653,
        @"VLWL": @190,
    };
    return iconTypes[identifier].integerValue;
}

static id YTMCreatePivotRenderer(NSString *identifier) {
    Class rendererClass = NSClassFromString(@"YTIPivotBarRenderer");
    SEL selector = NSSelectorFromString(@"pivotSupportedRenderersWithBrowseId:title:iconType:");
    if (![rendererClass respondsToSelector:selector]) return nil;

    return ((id (*)(id, SEL, NSString *, NSString *, NSInteger))objc_msgSend)(
        rendererClass,
        selector,
        identifier,
        YTMTitleForPivotIdentifier(identifier),
        YTMIconTypeForPivotIdentifier(identifier)
    );
}

static const void *YTMStartupSelectionAssociation = &YTMStartupSelectionAssociation;
static const void *YTMTabBlurAssociation = &YTMTabBlurAssociation;

%group YTMTabBarHooks

%hook YTPivotBarView
- (void)setRenderer:(id)renderer {
    NSMutableArray *items = YTMSafeValueForKey(renderer, @"itemsArray");
    if ([items isKindOfClass:NSMutableArray.class]) {
        NSMutableDictionary<NSString *, id> *available = [NSMutableDictionary dictionary];
        for (id item in items.copy) {
            NSString *identifier = YTMPivotIdentifierForSupportedRenderer(item);
            if (identifier.length > 0) available[identifier] = item;
        }

        NSMutableArray *ordered = [NSMutableArray array];
        for (NSString *identifier in YTMStringArray(@"activeTabs")) {
            id item = available[identifier] ?: YTMCreatePivotRenderer(identifier);
            if (item) [ordered addObject:item];
        }

        if (ordered.count > 0) {
            [items removeAllObjects];
            [items addObjectsFromArray:ordered];
        }
    }
    %orig(renderer);
}

- (void)layoutSubviews {
    %orig;

    UIVisualEffectView *blur = objc_getAssociatedObject(self, YTMTabBlurAssociation);
    if (YTMBool(@"translucentTabBar")) {
        if (!blur) {
            UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? UIBlurEffectStyleSystemThinMaterialDark
                : UIBlurEffectStyleSystemThinMaterialLight;
            blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
            blur.userInteractionEnabled = NO;
            blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self insertSubview:blur atIndex:0];
            objc_setAssociatedObject(self, YTMTabBlurAssociation, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        blur.frame = self.bounds;
        self.backgroundColor = UIColor.clearColor;
    } else if (blur) {
        [blur removeFromSuperview];
        objc_setAssociatedObject(self, YTMTabBlurAssociation, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end

%hook YTPivotBarIndicatorView
- (void)setFillColor:(UIColor *)color {
    %orig(YTMBool(@"removeIndicators") ? UIColor.clearColor : color);
}

- (void)setBorderColor:(UIColor *)color {
    %orig(YTMBool(@"removeIndicators") ? UIColor.clearColor : color);
}
%end

%hook YTPivotBarItemView
- (void)setRenderer:(id)renderer {
    %orig(renderer);
    if (!YTMBool(@"removeLabels")) return;

    UIButton *button = YTMSafeValueForKey(self, @"navigationButton");
    if ([button respondsToSelector:@selector(setTitle:forState:)]) {
        [button setTitle:@"" forState:UIControlStateNormal];
    }
    SEL resizeSelector = NSSelectorFromString(@"setSizeWithPaddingAndInsets:");
    if ([button respondsToSelector:resizeSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(button, resizeSelector, NO);
    }
}
%end

%hook YTPivotBarViewController
- (void)selectItemWithPivotIdentifier:(NSString *)identifier {
    if (identifier.length > 0) YTMCurrentPivotIdentifier = identifier.copy;
    %orig(identifier);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    if ([objc_getAssociatedObject(self, YTMStartupSelectionAssociation) boolValue]) return;
    objc_setAssociatedObject(self, YTMStartupSelectionAssociation, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSString *startup = YTMString(@"startupPivot");
    if (![YTMStringArray(@"activeTabs") containsObject:startup]) {
        startup = YTMStringArray(@"activeTabs").firstObject;
    }
    if (startup.length == 0) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        SEL selector = NSSelectorFromString(@"selectItemWithPivotIdentifier:");
        if ([self respondsToSelector:selector]) {
            ((void (*)(id, SEL, NSString *))objc_msgSend)(self, selector, startup);
        }
    });
}
%end

%end

%ctor {
    if (YTMIsSupportedYouTubeVersion()) {
        %init(YTMTabBarHooks);
    }
}
