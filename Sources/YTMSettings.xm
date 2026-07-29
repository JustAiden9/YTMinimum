#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "YTMCommon.h"
#import "YTMYouTube.h"

// YouTube walks its own category list when building the settings screen, so
// YTMinimum registers one extra category and fills it with native rows. This is
// the same approach YTLite uses, which keeps the page looking stock.
static const NSInteger YTMSettingsCategory = 789;
static NSString *const YTMSettingsItemIdentifier = @"YTMinimumSettingItem";

static UIColor *YTMAccentColor(void) {
    return [UIColor colorWithRed:0.42 green:0.71 blue:1.0 alpha:1.0];
}

#pragma mark - Shared helpers

static void YTMShowToast(NSString *message, id responder) {
    Class eventClass = objc_lookUpClass("YTToastResponderEvent");
    if (!eventClass || !responder) return;

    YTToastResponderEvent *event = [eventClass eventWithMessage:message firstResponder:responder];
    [event send];
}

static NSString *YTMRestartNotice(void) {
    return @"Restart YouTube to apply";
}

static YTSettingsSectionItem *YTMSwitchItem(NSString *title,
                                            NSString *description,
                                            NSString *key,
                                            void (^didChange)(BOOL enabled)) {
    return [%c(YTSettingsSectionItem) switchItemWithTitle:title
                                        titleDescription:description
                                 accessibilityIdentifier:YTMSettingsItemIdentifier
                                                switchOn:YTMBool(key)
                                             switchBlock:^BOOL(__unused YTSettingsCell *cell, BOOL enabled) {
        YTMSetBool(key, enabled);
        if (didChange) didChange(enabled);
        return YES;
    }
                                           settingItemId:0];
}

static YTSettingsSectionItem *YTMPageItem(NSString *title,
                                          NSString *description,
                                          NSString *detail,
                                          BOOL (^select)(void)) {
    NSString *(^detailBlock)(void) = detail.length > 0 ? ^NSString *{ return detail; } : (NSString *(^)(void))nil;
    return [%c(YTSettingsSectionItem) itemWithTitle:title
                                  titleDescription:description
                           accessibilityIdentifier:YTMSettingsItemIdentifier
                                   detailTextBlock:detailBlock
                                       selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
        return select ? select() : YES;
    }];
}

static void YTMPushPicker(id manager,
                          YTSettingsViewController *settings,
                          NSString *title,
                          NSArray *rows,
                          NSUInteger selectedIndex) {
    id responder = [manager respondsToSelector:@selector(parentResponder)] ? [manager parentResponder] : nil;
    YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:title
                                                                                     pickerSectionTitle:nil
                                                                                                   rows:rows
                                                                                      selectedItemIndex:selectedIndex
                                                                                        parentResponder:responder];
    [settings pushViewController:picker];
}

// One row per choice, checkmarked like YouTube's own option lists.
static YTSettingsSectionItem *YTMChoiceItem(id manager,
                                            YTSettingsViewController *settings,
                                            NSString *title,
                                            NSString *description,
                                            NSString *key,
                                            NSArray<NSString *> *choices) {
    __weak YTSettingsViewController *weakSettings = settings;
    NSInteger (^currentIndex)(void) = ^NSInteger {
        return MIN(MAX(YTMInteger(key), 0), (NSInteger)choices.count - 1);
    };

    return [%c(YTSettingsSectionItem) itemWithTitle:title
                                  titleDescription:description
                           accessibilityIdentifier:YTMSettingsItemIdentifier
                                   detailTextBlock:^NSString *{
        return choices[currentIndex()];
    }
                                       selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSString *choice in choices) {
            [rows addObject:[%c(YTSettingsSectionItem) checkmarkItemWithTitle:choice
                                                            titleDescription:nil
                                                                 selectBlock:^BOOL(__unused YTSettingsCell *pickerCell, NSUInteger selected) {
                YTMSetInteger(key, (NSInteger)selected);
                [weakSettings reloadData];
                return YES;
            }]];
        }
        YTMPushPicker(manager, settings, title, rows, (NSUInteger)currentIndex());
        return YES;
    }];
}

#pragma mark - Color rows

// UIColorPickerViewController needs a delegate that outlives the presentation,
// so each row keeps its own until the picker is dismissed.
@interface YTMColorPickerCoordinator : NSObject <UIColorPickerViewControllerDelegate>
@property(nonatomic, copy) NSString *key;
@property(nonatomic, strong) YTMColorPickerCoordinator *selfReference;
@property(nonatomic, weak) YTSettingsViewController *settings;
@end

@implementation YTMColorPickerCoordinator

- (void)presentForTitle:(NSString *)title {
    UIViewController *presenter = nil;
    Class utilsClass = objc_lookUpClass("YTUIUtils");
    if ([utilsClass respondsToSelector:@selector(topViewControllerForPresenting)]) {
        presenter = [utilsClass topViewControllerForPresenting];
    }
    if (!presenter) {
        self.selfReference = nil;
        return;
    }

    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.title = title;
    picker.selectedColor = YTMColor(self.key);
    picker.supportsAlpha = NO;
    picker.delegate = self;
    [presenter presentViewController:picker animated:YES completion:nil];
}

- (void)storeColor:(UIColor *)color {
    if (!color || self.key.length == 0) return;
    YTMSetObject(self.key, YTMHexStringFromColor(color));
    [self.settings reloadData];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    [self storeColor:viewController.selectedColor];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    [self storeColor:viewController.selectedColor];
    self.selfReference = nil;
}

@end

static YTSettingsSectionItem *YTMColorItem(YTSettingsViewController *settings,
                                           NSString *title,
                                           NSString *description,
                                           NSString *key) {
    __weak YTSettingsViewController *weakSettings = settings;
    return [%c(YTSettingsSectionItem) itemWithTitle:title
                                  titleDescription:description
                           accessibilityIdentifier:YTMSettingsItemIdentifier
                                   detailTextBlock:^NSString *{
        return YTMString(key).uppercaseString;
    }
                                       selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
        YTMColorPickerCoordinator *coordinator = [YTMColorPickerCoordinator new];
        coordinator.key = key;
        coordinator.settings = weakSettings;
        coordinator.selfReference = coordinator;
        [coordinator presentForTitle:title];
        return YES;
    }];
}

#pragma mark - Tab order editor

static void YTMRefreshPivotBar(void) {
    Class controllerClass = objc_lookUpClass("YTHeaderContentComboViewController");
    if (!controllerClass) return;

    YTHeaderContentComboViewController *controller = [[controllerClass alloc] init];
    if ([controller respondsToSelector:@selector(refreshPivotBar)]) {
        [controller refreshPivotBar];
    }
}

@interface YTMTabOrderController : UITableViewController
@property(nonatomic, strong) NSMutableArray<NSString *> *activeTabs;
@property(nonatomic, strong) NSMutableArray<NSString *> *inactiveTabs;
@end

@implementation YTMTabOrderController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"Tab order";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.activeTabs = [YTMStringArray(@"activeTabs") mutableCopy];
    self.inactiveTabs = [YTMStringArray(@"inactiveTabs") mutableCopy];
    if (self.activeTabs.count == 0) self.activeTabs = [YTMDefaultActiveTabs() mutableCopy];
    [self setEditing:YES animated:NO];
    self.tableView.allowsSelectionDuringEditing = NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.activeTabs.count : self.inactiveTabs.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Active tabs" : @"Inactive tabs";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 1) return nil;
    return @"Drag the handles to reorder active tabs. Use + and − to move tabs between the lists. Up to six tabs can be active.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    NSString *identifier = indexPath.section == 0 ? self.activeTabs[indexPath.row] : self.inactiveTabs[indexPath.row];
    cell.textLabel.text = YTMTitleForPivotIdentifier(identifier);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleInsert;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (self.activeTabs.count <= 1) {
            [self showMessage:@"At least one tab must stay active."];
            return;
        }
        NSString *identifier = self.activeTabs[indexPath.row];
        [self.activeTabs removeObjectAtIndex:indexPath.row];
        [self.inactiveTabs addObject:identifier];
    } else {
        if (self.activeTabs.count >= 6) {
            [self showMessage:@"Only six tabs can be active."];
            return;
        }
        NSString *identifier = self.inactiveTabs[indexPath.row];
        [self.inactiveTabs removeObjectAtIndex:indexPath.row];
        [self.activeTabs addObject:identifier];
    }
    [self persistTabs];
    [tableView reloadData];
}

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.section != 0 || destinationIndexPath.section != 0) {
        [tableView reloadData];
        return;
    }
    NSString *identifier = self.activeTabs[sourceIndexPath.row];
    [self.activeTabs removeObjectAtIndex:sourceIndexPath.row];
    [self.activeTabs insertObject:identifier atIndex:destinationIndexPath.row];
    [self persistTabs];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (proposedDestinationIndexPath.section != 0) {
        return [NSIndexPath indexPathForRow:MAX(0, (NSInteger)self.activeTabs.count - 1) inSection:0];
    }
    return proposedDestinationIndexPath;
}

- (void)persistTabs {
    YTMSetObject(@"activeTabs", self.activeTabs.copy);
    YTMSetObject(@"inactiveTabs", self.inactiveTabs.copy);
    if (![self.activeTabs containsObject:YTMString(@"startupPivot")]) {
        YTMSetObject(@"startupPivot", self.activeTabs.firstObject);
    }
    YTMRefreshPivotBar();
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"YTMinimum"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Pages

static NSArray<YTSettingsSectionItem *> *YTMFeedRows(id manager) {
    id responder = [manager respondsToSelector:@selector(parentResponder)] ? [manager parentResponder] : nil;
    void (^notify)(BOOL) = ^(__unused BOOL enabled) {
        YTMShowToast(YTMRestartNotice(), responder);
    };

    return @[
        YTMSwitchItem(@"Remove ads", @"Hides video ads, promoted feed items, and Premium upsells.", @"noAds", notify),
        YTMSwitchItem(@"Hide Shorts", @"Removes Shorts shelves from Home, Search, and other feeds.", @"hideShorts", notify),
        YTMSwitchItem(@"Keep Shorts in Subscriptions", @"Leaves Shorts visible in the Subscriptions tab only.", @"keepSubsShorts", notify),
        YTMSwitchItem(@"Remove horizontal shelves", @"Removes side-scrolling rows such as Continue watching. Depends on YouTube's layout names.", @"removeHorizontalFeeds", notify),
        YTMSwitchItem(@"Remove community posts", @"Removes text and image posts from feeds. Depends on YouTube's layout names.", @"removeCommunityPosts", notify),
        YTMSwitchItem(@"Remove mixes", @"Removes auto-generated mixes and radio playlists. Depends on YouTube's layout names.", @"removeMixes", notify),
        YTMSwitchItem(@"Remove More topics", @"Removes the topic shelf from the bottom of Home. Depends on YouTube's layout names.", @"removeMoreTopics", notify),
        YTMSwitchItem(@"Remove Playables", @"Removes Playables mini-games. Depends on YouTube's layout names.", @"removePlayables", notify),
        YTMSwitchItem(@"Remove promo banners", @"Removes statement banners and Premium promo strips.", @"removePromoBanners", notify),
        YTMSwitchItem(@"Fix cover artwork", @"Loads channel and playlist art from an alternate host when it fails.", @"fixCovers", nil),
    ];
}

static NSArray<NSString *> *YTMPlaybackRateLabels(void) {
    return @[@"0.25×", @"0.5×", @"0.75×", @"1.0×", @"1.25×", @"1.5×", @"1.75×", @"2.0×", @"3.0×", @"4.0×", @"5.0×"];
}

static NSArray<YTSettingsSectionItem *> *YTMPlayerRows(id manager, YTSettingsViewController *settings) {
    return @[
        YTMChoiceItem(manager, settings, @"Progress bar style", @"Solid uses the main color; gradient adds the highlight color.", @"progressBarStyle", @[@"Solid", @"Gradient"]),
        YTMColorItem(settings, @"Main color", @"Played portion of the progress bar.", @"mainColor"),
        YTMColorItem(settings, @"Gradient color", @"Highlight used by the gradient style.", @"gradientColor"),
        YTMColorItem(settings, @"Scrubber color", @"The dot you drag along the progress bar.", @"scrubberColor"),
        YTMChoiceItem(manager, settings, @"Default playback rate", @"Applied shortly after a video starts.", @"playbackRateIndex", YTMPlaybackRateLabels()),
        YTMSwitchItem(@"Background playback", @"Keeps audio playing when YouTube is backgrounded or the screen locks.", @"backgroundPlayback", nil),
        YTMSwitchItem(@"Force mini player", @"Keeps the mini player available for videos that normally block it.", @"miniplayer", nil),
        YTMSwitchItem(@"Disable autoplay", @"Opens videos paused instead of starting playback.", @"disableAutoplay", nil),
        YTMSwitchItem(@"Skip content warnings", @"Confirms sensitive-content prompts automatically.", @"noContentWarning", nil),
        YTMSwitchItem(@"Disable hints", @"Suppresses YouTube's tooltip hints.", @"noHints", nil),
        YTMSwitchItem(@"Open videos in fullscreen", @"Enters fullscreen as soon as a video opens. Shorts are excluded.", @"autoFullscreen", nil),
        YTMSwitchItem(@"Exit fullscreen when finished", @"Leaves fullscreen after playback ends.", @"exitFullscreen", nil),
        YTMChoiceItem(manager, settings, @"Left side gesture", @"Vertical swipe on the left half of the player.", @"leftGesture", @[@"Disabled", @"Brightness", @"Volume"]),
        YTMChoiceItem(manager, settings, @"Right side gesture", @"Vertical swipe on the right half of the player.", @"rightGesture", @[@"Disabled", @"Brightness", @"Volume"]),
    ];
}

static NSArray<YTSettingsSectionItem *> *YTMTabBarRows(id manager, YTSettingsViewController *settings) {
    __weak YTSettingsViewController *weakSettings = settings;
    NSArray<NSString *> *activeTabs = YTMStringArray(@"activeTabs");
    if (activeTabs.count == 0) activeTabs = YTMDefaultActiveTabs();

    NSMutableArray<NSString *> *startupTitles = [NSMutableArray array];
    for (NSString *identifier in activeTabs) {
        [startupTitles addObject:YTMTitleForPivotIdentifier(identifier)];
    }

    YTSettingsSectionItem *startup = [%c(YTSettingsSectionItem) itemWithTitle:@"Startup page"
                                                            titleDescription:@"The tab YouTube opens on."
                                                     accessibilityIdentifier:YTMSettingsItemIdentifier
                                                             detailTextBlock:^NSString *{
        return YTMTitleForPivotIdentifier(YTMString(@"startupPivot"));
    }
                                                                 selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
        NSMutableArray *rows = [NSMutableArray array];
        [activeTabs enumerateObjectsUsingBlock:^(__unused NSString *identifier, NSUInteger position, __unused BOOL *stop) {
            [rows addObject:[%c(YTSettingsSectionItem) checkmarkItemWithTitle:startupTitles[position]
                                                            titleDescription:nil
                                                                 selectBlock:^BOOL(__unused YTSettingsCell *pickerCell, NSUInteger selected) {
                if (selected < activeTabs.count) YTMSetObject(@"startupPivot", activeTabs[selected]);
                [weakSettings reloadData];
                return YES;
            }]];
        }];

        NSUInteger startupIndex = [activeTabs indexOfObject:YTMString(@"startupPivot")];
        YTMPushPicker(manager, settings, @"Startup page", rows, startupIndex == NSNotFound ? 0 : startupIndex);
        return YES;
    }];

    YTSettingsSectionItem *order = YTMPageItem(@"Tab order", @"Choose which tabs appear and how they are ordered.", @"›", ^BOOL {
        YTMTabOrderController *controller = [YTMTabOrderController new];
        controller.overrideUserInterfaceStyle = weakSettings.traitCollection.userInterfaceStyle;
        [weakSettings pushViewController:controller];
        return YES;
    });

    return @[
        startup,
        order,
        YTMSwitchItem(@"Translucent tab bar", @"Blurs the tab bar background.", @"translucentTabBar", ^(__unused BOOL enabled) {
            YTMRefreshPivotBar();
        }),
        YTMSwitchItem(@"Hide tab labels", @"Shows tab icons without their titles.", @"removeLabels", ^(__unused BOOL enabled) {
            YTMRefreshPivotBar();
        }),
        YTMSwitchItem(@"Hide tab indicators", @"Removes the red dots on tab icons.", @"removeIndicators", ^(__unused BOOL enabled) {
            YTMRefreshPivotBar();
        }),
    ];
}

static NSArray<YTSettingsSectionItem *> *YTMAboutRows(id manager, YTSettingsViewController *settings) {
    __weak YTSettingsViewController *weakSettings = settings;
    id responder = [manager respondsToSelector:@selector(parentResponder)] ? [manager parentResponder] : nil;
    NSString *installed = YTMInstalledYouTubeVersion();

    NSString *compatibility;
    if ([installed isEqualToString:YTMSupportedYouTubeVersion]) {
        compatibility = @"Matched";
    } else if (YTMIsSupportedYouTubeVersion()) {
        compatibility = @"Untested";
    } else {
        compatibility = @"Unsupported";
    }

    NSString *tweakVersion = @PACKAGE_VERSION;

    return @[
        YTMPageItem(@"YTMinimum version", nil, tweakVersion, nil),
        YTMPageItem(@"YouTube version",
                    [NSString stringWithFormat:@"Built against %@.", YTMSupportedYouTubeVersion],
                    installed.length > 0 ? installed : @"Unknown",
                    nil),
        YTMPageItem(@"Compatibility",
                    @"Feed and player hooks only load for the YouTube release series this build targets.",
                    compatibility,
                    nil),
        YTMPageItem(@"Reset all settings", @"Restores every YTMinimum option to its default.", nil, ^BOOL {
            Class alertClass = objc_lookUpClass("YTAlertView");
            if (![alertClass respondsToSelector:@selector(confirmationDialogWithAction:actionTitle:cancelTitle:)]) {
                YTMResetSettings();
                [weakSettings reloadData];
                YTMShowToast(YTMRestartNotice(), responder);
                return YES;
            }

            YTAlertView *alert = [alertClass confirmationDialogWithAction:^{
                YTMResetSettings();
                [weakSettings reloadData];
                YTMShowToast(YTMRestartNotice(), responder);
            }
                                                             actionTitle:@"Reset"
                                                             cancelTitle:@"Cancel"];
            alert.title = @"YTMinimum";
            alert.subtitle = @"Reset every YTMinimum option to its default?";
            [alert show];
            return YES;
        }),
    ];
}

#pragma mark - Hooks

%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    NSArray *original = %orig;
    if ([original containsObject:@(YTMSettingsCategory)]) return original;

    NSMutableArray *order = [original mutableCopy];
    NSUInteger anchor = [order indexOfObject:@(1)];
    NSUInteger insertion = anchor == NSNotFound ? order.count : anchor + 1;
    [order insertObject:@(YTMSettingsCategory) atIndex:insertion];
    return order;
}
%end

%hook YTSettingsSectionController
- (void)setSelectedItem:(NSUInteger)selectedItem {
    if (selectedItem != NSNotFound) %orig;
}
%end

// Give YTMinimum's own rows an accent so the page is recognisable, the way
// YTLite tints its section.
%hook YTSettingsCell
- (void)layoutSubviews {
    %orig;
    if (![self.accessibilityIdentifier isEqualToString:YTMSettingsItemIdentifier]) return;

    id feedback = YTMSafeValueForKey(self, @"_touchFeedbackController");
    if ([feedback respondsToSelector:@selector(setFeedbackColor:)]) {
        [feedback setValue:YTMAccentColor() forKey:@"feedbackColor"];
    }

    id toggle = YTMSafeValueForKey(self, @"_switch");
    if ([toggle respondsToSelector:@selector(setOnTintColor:)]) {
        [toggle setValue:YTMAccentColor() forKey:@"onTintColor"];
    }
}
%end

%hook YTSettingsSectionItemManager
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category != YTMSettingsCategory) {
        %orig;
        return;
    }

    YTSettingsViewController *settings = YTMSafeValueForKey(self, @"_settingsViewControllerDelegate");
    if (!settings) return;

    __weak __typeof(self) weakSelf = self;
    __weak YTSettingsViewController *weakSettings = settings;
    NSMutableArray *items = [NSMutableArray array];

    [items addObject:YTMPageItem(@"Feed", @"Ads, Shorts, shelves, and cover art", @"›", ^BOOL {
        YTMPushPicker(weakSelf, weakSettings, @"Feed", YTMFeedRows(weakSelf), NSNotFound);
        return YES;
    })];

    [items addObject:YTMPageItem(@"Player", @"Playback, colors, fullscreen, and gestures", @"›", ^BOOL {
        YTMPushPicker(weakSelf, weakSettings, @"Player", YTMPlayerRows(weakSelf, weakSettings), NSNotFound);
        return YES;
    })];

    [items addObject:YTMPageItem(@"Tab bar", @"Startup page, tab order, and appearance", @"›", ^BOOL {
        YTMPushPicker(weakSelf, weakSettings, @"Tab bar", YTMTabBarRows(weakSelf, weakSettings), NSNotFound);
        return YES;
    })];

    [items addObject:YTMPageItem(@"About", @"Version, compatibility, and reset", @"›", ^BOOL {
        YTMPushPicker(weakSelf, weakSettings, @"About", YTMAboutRows(weakSelf, weakSettings), NSNotFound);
        return YES;
    })];

    if ([settings respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        [settings setSectionItems:items
                      forCategory:YTMSettingsCategory
                            title:@"YTMinimum"
                             icon:nil
                 titleDescription:nil
                     headerHidden:NO];
    } else {
        [settings setSectionItems:items
                      forCategory:YTMSettingsCategory
                            title:@"YTMinimum"
                 titleDescription:nil
                     headerHidden:NO];
    }
}
%end

%ctor {
    %init;
}
