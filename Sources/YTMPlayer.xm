#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "YTMCommon.h"

@interface YTPlayabilityResolutionUserActionUIController : NSObject
@end

@interface YTMainAppVideoPlayerOverlayView : UIView
@end

static NSArray<NSNumber *> *YTMPlaybackRateValues(void) {
    return @[@0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
}

static UIColor *YTMProgressColor(void) {
    return YTMInteger(@"progressBarStyle") == 0 ? YTMColor(@"mainColor") : YTMColor(@"gradientColor");
}

static void YTMSetPlaybackRateOnPlayer(id player) {
    NSInteger index = MIN(MAX(YTMInteger(@"playbackRateIndex"), 0), (NSInteger)YTMPlaybackRateValues().count - 1);
    if (index == 3) return;

    CGFloat rate = YTMPlaybackRateValues()[index].doubleValue;
    id overlay = YTMSafeValueForKey(player, @"activeVideoPlayerOverlay");
    SEL selector = NSSelectorFromString(@"setPlaybackRate:");
    id target = [overlay respondsToSelector:selector] ? overlay : player;
    if ([target respondsToSelector:selector]) {
        ((void (*)(id, SEL, CGFloat))objc_msgSend)(target, selector, rate);
    }
}

static void YTMEnterFullscreen(id player) {
    id delegate = YTMSafeValueForKey(player, @"_UIDelegate");
    if (!delegate) delegate = YTMSafeValueForKey(player, @"UIDelegate");
    SEL selector = NSSelectorFromString(@"showFullScreen");
    if ([delegate respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(delegate, selector);
    }
}

@interface YTMPlayerGestureHandler : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UIView *view;
@property(nonatomic, strong) UIPanGestureRecognizer *pan;
@property(nonatomic, strong) MPVolumeView *volumeView;
@property(nonatomic, weak) UISlider *volumeSlider;
@property(nonatomic) NSInteger activeAction;
@property(nonatomic) CGFloat initialValue;
- (instancetype)initWithView:(UIView *)view;
@end

@implementation YTMPlayerGestureHandler

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self) {
        self.view = view;
        self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        self.pan.delegate = self;
        self.pan.maximumNumberOfTouches = 1;
        self.pan.cancelsTouchesInView = NO;
        [view addGestureRecognizer:self.pan];

        self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-20, -20, 1, 1)];
        self.volumeView.alpha = 0.001;
        [view addSubview:self.volumeView];
        for (UIView *subview in self.volumeView.subviews) {
            if ([subview isKindOfClass:UISlider.class]) {
                self.volumeSlider = (UISlider *)subview;
                break;
            }
        }
    }
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint velocity = [gestureRecognizer velocityInView:self.view];
    if (fabs(velocity.y) <= fabs(velocity.x)) return NO;

    CGPoint location = [gestureRecognizer locationInView:self.view];
    NSInteger preference = location.x < CGRectGetMidX(self.view.bounds)
        ? YTMInteger(@"leftGesture")
        : YTMInteger(@"rightGesture");
    return preference == 1 || preference == 2;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!self.view) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [gesture locationInView:self.view];
        self.activeAction = location.x < CGRectGetMidX(self.view.bounds)
            ? YTMInteger(@"leftGesture")
            : YTMInteger(@"rightGesture");
        self.initialValue = self.activeAction == 1
            ? UIScreen.mainScreen.brightness
            : self.volumeSlider.value;
    }

    CGFloat height = MAX(CGRectGetHeight(self.view.bounds), 1);
    CGFloat delta = -[gesture translationInView:self.view].y / height;
    CGFloat value = MIN(MAX(self.initialValue + delta, 0), 1);

    if (self.activeAction == 1) {
        UIScreen.mainScreen.brightness = value;
    } else if (self.activeAction == 2 && self.volumeSlider) {
        [self.volumeSlider setValue:value animated:NO];
        [self.volumeSlider sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

@end

static const void *YTMGestureHandlerAssociation = &YTMGestureHandlerAssociation;

%group YTMPlayerHooks

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground {
    return YTMBool(@"backgroundPlayback") ? YES : %orig;
}
%end

%hook MLVideo
- (BOOL)playableInBackground {
    return YTMBool(@"backgroundPlayback") ? YES : %orig;
}
%end

%hook YTWatchMiniBarViewController
- (void)updateMiniBarPlayerStateFromRenderer {
    if (!YTMBool(@"miniplayer")) %orig;
}
%end

%hook YTPlaybackConfig
- (void)setStartPlayback:(BOOL)startPlayback {
    %orig(YTMBool(@"disableAutoplay") ? NO : startPlayback);
}
%end

%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert {
    if (YTMBool(@"noContentWarning")) {
        SEL selector = NSSelectorFromString(@"confirmAlertDidPressConfirm");
        if ([self respondsToSelector:selector]) {
            ((void (*)(id, SEL))objc_msgSend)(self, selector);
        }
    } else {
        %orig;
    }
}
%end

%hook YTSettings
- (BOOL)areHintsDisabled {
    return YTMBool(@"noHints") ? YES : %orig;
}

- (void)setHintsDisabled:(BOOL)disabled {
    %orig(YTMBool(@"noHints") ? YES : disabled);
}
%end

%hook YTUserDefaults
- (BOOL)areHintsDisabled {
    return YTMBool(@"noHints") ? YES : %orig;
}

- (void)setHintsDisabled:(BOOL)disabled {
    %orig(YTMBool(@"noHints") ? YES : disabled);
}
%end

%hook YTPlayerViewController
- (void)loadWithPlayerTransition:(id)transition playbackConfig:(id)playbackConfig {
    %orig(transition, playbackConfig);
    __weak id weakPlayer = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id player = weakPlayer;
        if (!player) return;
        YTMSetPlaybackRateOnPlayer(player);
        if (YTMBool(@"autoFullscreen") &&
            !YTMDescriptionContainsAny(YTMSafeValueForKey(player, @"parentViewController"), @[@"shorts", @"reel"])) {
            YTMEnterFullscreen(player);
        }
    });
}
%end

%hook YTWatchFlowController
- (BOOL)shouldExitFullScreenOnFinish {
    return YTMBool(@"exitFullscreen") ? YES : %orig;
}
%end

%hook YTInlinePlayerBarContainerView
- (id)quietProgressBarColor {
    return YTMProgressColor();
}

- (void)setScrubberColor:(UIColor *)color {
    %orig(YTMColor(@"scrubberColor"));
}
%end

%hook YTSegmentableInlinePlayerBarView
- (void)setPlayedProgressBarColor:(UIColor *)color {
    %orig(YTMProgressColor());
}

- (void)setPlayingProgressBarColor:(UIColor *)color {
    %orig(YTMProgressColor());
}

- (void)setProgressBarColor:(UIColor *)color {
    %orig(YTMProgressColor());
}

- (void)setScrubberColor:(UIColor *)color {
    %orig(YTMColor(@"scrubberColor"));
}

- (void)setBufferedProgressBarColor:(UIColor *)color {
    UIColor *highlight = [YTMColor(@"gradientColor") colorWithAlphaComponent:0.45];
    %orig(YTMInteger(@"progressBarStyle") == 1 ? highlight : color);
}
%end

%hook YTMainAppVideoPlayerOverlayView
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;

    YTMPlayerGestureHandler *handler = objc_getAssociatedObject(self, YTMGestureHandlerAssociation);
    if (!handler) {
        handler = [[YTMPlayerGestureHandler alloc] initWithView:self];
        objc_setAssociatedObject(self,
                                 YTMGestureHandlerAssociation,
                                 handler,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end

%end

%ctor {
    if (YTMIsSupportedYouTubeVersion()) {
        %init(YTMPlayerHooks);
    }
}
