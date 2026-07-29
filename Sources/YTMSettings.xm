#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "YTMCommon.h"

static const NSInteger YTMSettingsCategory = 789;

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

@interface YTSettingsCell : UICollectionViewCell
@end

@interface YTSettingsSectionController : NSObject
- (void)setSelectedItem:(NSUInteger)selectedItem;
@end

@interface YTSettingsSectionItem : NSObject
+ (instancetype)itemWithTitle:(NSString *)title
             titleDescription:(NSString *)titleDescription
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              detailTextBlock:(NSString *(^)(void))detailTextBlock
                  selectBlock:(BOOL (^)(YTSettingsCell *cell, NSUInteger index))selectBlock;
@end

@interface YTSettingsViewController : UIViewController
- (void)pushViewController:(UIViewController *)viewController;
- (void)setSectionItems:(NSArray *)items
            forCategory:(NSInteger)category
                  title:(NSString *)title
                   icon:(UIImage *)icon
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
- (void)setSectionItems:(NSArray *)items
            forCategory:(NSInteger)category
                  title:(NSString *)title
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
@end

@interface YTSettingsSectionItemManager : NSObject
- (id)parentResponder;
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry;
@end

typedef NS_ENUM(NSInteger, YTMSettingRowKind) {
    YTMSettingRowKindSwitch,
    YTMSettingRowKindAction,
    YTMSettingRowKindColor,
};

@interface YTMSettingRow : NSObject
@property(nonatomic) YTMSettingRowKind kind;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;
@property(nonatomic, copy) NSString *key;
@property(nonatomic, copy) NSString *(^detailProvider)(void);
@property(nonatomic, copy) void (^action)(UIViewController *controller);
+ (instancetype)switchRow:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
+ (instancetype)actionRow:(NSString *)title
                 subtitle:(NSString *)subtitle
                   detail:(NSString *(^)(void))detail
                   action:(void (^)(UIViewController *controller))action;
+ (instancetype)colorRow:(NSString *)title key:(NSString *)key;
@end

@implementation YTMSettingRow
+ (instancetype)switchRow:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key {
    YTMSettingRow *row = [self new];
    row.kind = YTMSettingRowKindSwitch;
    row.title = title;
    row.subtitle = subtitle;
    row.key = key;
    return row;
}

+ (instancetype)actionRow:(NSString *)title
                 subtitle:(NSString *)subtitle
                   detail:(NSString *(^)(void))detail
                   action:(void (^)(UIViewController *controller))action {
    YTMSettingRow *row = [self new];
    row.kind = YTMSettingRowKindAction;
    row.title = title;
    row.subtitle = subtitle;
    row.detailProvider = detail;
    row.action = action;
    return row;
}

+ (instancetype)colorRow:(NSString *)title key:(NSString *)key {
    YTMSettingRow *row = [self new];
    row.kind = YTMSettingRowKindColor;
    row.title = title;
    row.key = key;
    return row;
}
@end

@interface YTMPreferenceSwitch : UISwitch
@property(nonatomic, copy) NSString *preferenceKey;
@end

@implementation YTMPreferenceSwitch
@end

@interface YTMSettingsListController : UITableViewController <UIColorPickerViewControllerDelegate>
@property(nonatomic, copy) NSArray<YTMSettingRow *> *rows;
@property(nonatomic, copy) NSString *pendingColorKey;
- (instancetype)initWithTitle:(NSString *)title rows:(NSArray<YTMSettingRow *> *)rows;
@end

@implementation YTMSettingsListController

- (instancetype)initWithTitle:(NSString *)title rows:(NSArray<YTMSettingRow *> *)rows {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = title;
        self.rows = rows;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 64;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YTMSettingRow *row = self.rows[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = row.kind == YTMSettingRowKindSwitch ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;

    if (row.kind == YTMSettingRowKindSwitch) {
        YTMPreferenceSwitch *toggle = [YTMPreferenceSwitch new];
        toggle.preferenceKey = row.key;
        toggle.on = YTMBool(row.key);
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if (row.kind == YTMSettingRowKindColor) {
        UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        swatch.layer.cornerRadius = 15;
        swatch.layer.borderWidth = 2;
        swatch.layer.borderColor = UIColor.secondaryLabelColor.CGColor;
        swatch.backgroundColor = YTMColor(row.key);
        cell.accessoryView = swatch;
    } else {
        NSString *detail = row.detailProvider ? row.detailProvider() : nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (detail.length > 0) {
            UILabel *label = [UILabel new];
            label.text = detail;
            label.textColor = UIColor.secondaryLabelColor;
            label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            [label sizeToFit];
            cell.accessoryView = label;
        }
    }

    return cell;
}

- (void)switchChanged:(YTMPreferenceSwitch *)sender {
    YTMSetBool(sender.preferenceKey, sender.isOn);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YTMSettingRow *row = self.rows[indexPath.row];

    if (row.kind == YTMSettingRowKindColor) {
        self.pendingColorKey = row.key;
        UIColorPickerViewController *picker = [UIColorPickerViewController new];
        picker.title = row.title;
        picker.selectedColor = YTMColor(row.key);
        picker.supportsAlpha = NO;
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else if (row.kind == YTMSettingRowKindAction && row.action) {
        row.action(self);
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    if (self.pendingColorKey.length > 0) {
        YTMSetObject(self.pendingColorKey, YTMHexStringFromColor(viewController.selectedColor));
        [self.tableView reloadData];
    }
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    if (self.pendingColorKey.length > 0) {
        YTMSetObject(self.pendingColorKey, YTMHexStringFromColor(viewController.selectedColor));
        [self.tableView reloadData];
    }
}

@end

static void YTMPresentChoices(UIViewController *controller,
                              NSString *title,
                              NSArray<NSString *> *choices,
                              NSInteger selected,
                              void (^selection)(NSInteger index)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [choices enumerateObjectsUsingBlock:^(NSString *choice, NSUInteger index, BOOL *stop) {
        NSString *label = index == selected ? [NSString stringWithFormat:@"✓ %@", choice] : choice;
        [alert addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            selection(index);
        }]];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = controller.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds),
                                                                     CGRectGetMaxY(controller.view.bounds),
                                                                     1,
                                                                     1);
    }
    [controller presentViewController:alert animated:YES completion:nil];
}

static YTMSettingsListController *YTMFeedController(void) {
    NSArray *rows = @[
        [YTMSettingRow switchRow:@"Remove ads" subtitle:@"Removes in-app and video ads." key:@"noAds"],
        [YTMSettingRow switchRow:@"Hide Shorts videos" subtitle:@"Hides Shorts from Home, Recommended, and other feeds." key:@"hideShorts"],
        [YTMSettingRow switchRow:@"Keep Shorts in Subscriptions" subtitle:@"Keeps Shorts visible only in the Subscriptions tab." key:@"keepSubsShorts"],
        [YTMSettingRow switchRow:@"Remove \"More topics\"" subtitle:@"Removes the More topics shelf from the feed." key:@"removeMoreTopics"],
        [YTMSettingRow switchRow:@"Remove community posts" subtitle:@"Removes community posts from the feed." key:@"removeCommunityPosts"],
        [YTMSettingRow switchRow:@"Remove mixes" subtitle:@"Removes YouTube-generated mix playlists." key:@"removeMixes"],
        [YTMSettingRow switchRow:@"Remove Live videos" subtitle:@"Removes live videos from the Home tab." key:@"removeLive"],
        [YTMSettingRow switchRow:@"Remove horizontal feeds" subtitle:@"Removes horizontal shelves such as News and Continue Watching." key:@"removeHorizontalFeeds"],
        [YTMSettingRow switchRow:@"Remove playables" subtitle:@"Removes Playables mini-games from the feed." key:@"removePlayables"],
        [YTMSettingRow switchRow:@"Fix covers" subtitle:@"Uses an alternate image host when cover artwork fails to load." key:@"fixCovers"],
    ];
    return [[YTMSettingsListController alloc] initWithTitle:@"Feed" rows:rows];
}

static NSArray<NSString *> *YTMPlaybackRates(void) {
    return @[@"0.25×", @"0.5×", @"0.75×", @"1.0×", @"1.25×", @"1.5×", @"1.75×", @"2.0×", @"3.0×", @"4.0×", @"5.0×"];
}

static NSArray<NSString *> *YTMGestureChoices(void) {
    return @[@"Disabled", @"Brightness", @"Volume"];
}

static YTMSettingsListController *YTMPlayerController(void) {
    __block YTMSettingsListController *result;

    YTMSettingRow *style = [YTMSettingRow actionRow:@"Progress bar style"
                                           subtitle:@"Choose a solid or gradient progress bar."
                                             detail:^NSString *{
        return YTMInteger(@"progressBarStyle") == 0 ? @"Solid" : @"Gradient";
    } action:^(UIViewController *controller) {
        YTMPresentChoices(controller, @"Progress bar style", @[@"Solid", @"Gradient"], YTMInteger(@"progressBarStyle"), ^(NSInteger index) {
            YTMSetInteger(@"progressBarStyle", index);
            [((UITableViewController *)controller).tableView reloadData];
        });
    }];

    YTMSettingRow *rate = [YTMSettingRow actionRow:@"Default playback rate"
                                          subtitle:@"Overrides the playback speed when a video opens."
                                            detail:^NSString *{
        NSInteger index = MIN(MAX(YTMInteger(@"playbackRateIndex"), 0), (NSInteger)YTMPlaybackRates().count - 1);
        return YTMPlaybackRates()[index];
    } action:^(UIViewController *controller) {
        YTMPresentChoices(controller, @"Default playback rate", YTMPlaybackRates(), YTMInteger(@"playbackRateIndex"), ^(NSInteger index) {
            YTMSetInteger(@"playbackRateIndex", index);
            [((UITableViewController *)controller).tableView reloadData];
        });
    }];

    YTMSettingRow *leftGesture = [YTMSettingRow actionRow:@"Gesture for the left side"
                                                 subtitle:@"Swipe vertically on the left side of the player."
                                                   detail:^NSString *{
        NSInteger index = MIN(MAX(YTMInteger(@"leftGesture"), 0), (NSInteger)YTMGestureChoices().count - 1);
        return YTMGestureChoices()[index];
    } action:^(UIViewController *controller) {
        YTMPresentChoices(controller, @"Left-side gesture", YTMGestureChoices(), YTMInteger(@"leftGesture"), ^(NSInteger index) {
            YTMSetInteger(@"leftGesture", index);
            [((UITableViewController *)controller).tableView reloadData];
        });
    }];

    YTMSettingRow *rightGesture = [YTMSettingRow actionRow:@"Gesture for the right side"
                                                  subtitle:@"Swipe vertically on the right side of the player."
                                                    detail:^NSString *{
        NSInteger index = MIN(MAX(YTMInteger(@"rightGesture"), 0), (NSInteger)YTMGestureChoices().count - 1);
        return YTMGestureChoices()[index];
    } action:^(UIViewController *controller) {
        YTMPresentChoices(controller, @"Right-side gesture", YTMGestureChoices(), YTMInteger(@"rightGesture"), ^(NSInteger index) {
            YTMSetInteger(@"rightGesture", index);
            [((UITableViewController *)controller).tableView reloadData];
        });
    }];

    NSArray *rows = @[
        style,
        [YTMSettingRow colorRow:@"Main color" key:@"mainColor"],
        [YTMSettingRow colorRow:@"Gradient highlight" key:@"gradientColor"],
        [YTMSettingRow colorRow:@"Scrubber color" key:@"scrubberColor"],
        rate,
        [YTMSettingRow switchRow:@"Background playback" subtitle:@"Enables playback while YouTube is in the background or the screen is locked." key:@"backgroundPlayback"],
        [YTMSettingRow switchRow:@"Enable mini player" subtitle:@"Enables the mini player for videos that normally disable it." key:@"miniplayer"],
        [YTMSettingRow switchRow:@"Disable autoplay videos" subtitle:@"Prevents playback immediately after opening a video." key:@"disableAutoplay"],
        [YTMSettingRow switchRow:@"Skip content warning" subtitle:@"Automatically confirms sensitive-content warnings." key:@"noContentWarning"],
        [YTMSettingRow switchRow:@"Disable hints" subtitle:@"Disables creator hints shown during playback." key:@"noHints"],
        [YTMSettingRow switchRow:@"Play videos in fullscreen" subtitle:@"Automatically enters fullscreen when a video opens." key:@"autoFullscreen"],
        [YTMSettingRow switchRow:@"Exit fullscreen mode on finish" subtitle:@"Leaves fullscreen when playback finishes." key:@"exitFullscreen"],
        leftGesture,
        rightGesture,
    ];

    result = [[YTMSettingsListController alloc] initWithTitle:@"Player" rows:rows];
    return result;
}

static void YTMRefreshPivotBar(void) {
    Class controllerClass = NSClassFromString(@"YTHeaderContentComboViewController");
    id controller = controllerClass ? [controllerClass new] : nil;
    SEL selector = NSSelectorFromString(@"refreshPivotBar");
    if ([controller respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, selector);
    }
}

@interface YTMTabBarController : UITableViewController
@property(nonatomic, strong) NSMutableArray<NSString *> *activeTabs;
@property(nonatomic, strong) NSMutableArray<NSString *> *inactiveTabs;
@end

@implementation YTMTabBarController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"Tab bar";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.activeTabs = [YTMStringArray(@"activeTabs") mutableCopy];
    self.inactiveTabs = [YTMStringArray(@"inactiveTabs") mutableCopy];
    if (self.activeTabs.count == 0) self.activeTabs = [YTMDefaultActiveTabs() mutableCopy];
    [self setEditing:YES animated:NO];
    self.tableView.allowsSelectionDuringEditing = YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    return section == 1 ? self.activeTabs.count : self.inactiveTabs.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Main";
    return section == 1 ? @"Active tabs" : @"Inactive tabs";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) return @"Use + and − to enable or disable tabs. Drag active tabs to reorder them. Up to six tabs may be active.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];

    if (indexPath.section == 0) {
        NSArray *titles = @[@"Startup page", @"Translucent tab bar", @"Remove tab labels", @"Remove tab indicators"];
        cell.textLabel.text = titles[indexPath.row];
        if (indexPath.row == 0) {
            cell.detailTextLabel.text = YTMTitleForPivotIdentifier(YTMString(@"startupPivot"));
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            NSArray *keys = @[@"translucentTabBar", @"removeLabels", @"removeIndicators"];
            YTMPreferenceSwitch *toggle = [YTMPreferenceSwitch new];
            toggle.preferenceKey = keys[indexPath.row - 1];
            toggle.on = YTMBool(toggle.preferenceKey);
            [toggle addTarget:self action:@selector(tabSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else {
        NSString *identifier = indexPath.section == 1 ? self.activeTabs[indexPath.row] : self.inactiveTabs[indexPath.row];
        cell.textLabel.text = YTMTitleForPivotIdentifier(identifier);
    }
    return cell;
}

- (void)tabSwitchChanged:(YTMPreferenceSwitch *)sender {
    YTMSetBool(sender.preferenceKey, sender.isOn);
    YTMRefreshPivotBar();
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0 || indexPath.row != 0) return;

    NSMutableArray<NSString *> *choices = [NSMutableArray array];
    for (NSString *identifier in self.activeTabs) {
        [choices addObject:YTMTitleForPivotIdentifier(identifier)];
    }
    NSUInteger selected = [self.activeTabs indexOfObject:YTMString(@"startupPivot")];
    if (selected == NSNotFound) selected = 0;
    YTMPresentChoices(self, @"Startup page", choices, selected, ^(NSInteger index) {
        if (index < (NSInteger)self.activeTabs.count) {
            YTMSetObject(@"startupPivot", self.activeTabs[index]);
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationNone];
        }
    });
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) return UITableViewCellEditingStyleDelete;
    if (indexPath.section == 2) return UITableViewCellEditingStyleInsert;
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && editingStyle == UITableViewCellEditingStyleDelete) {
        if (self.activeTabs.count <= 1) {
            [self showLimitMessage:@"At least one tab must remain active."];
            return;
        }
        NSString *identifier = self.activeTabs[indexPath.row];
        [self.activeTabs removeObjectAtIndex:indexPath.row];
        [self.inactiveTabs addObject:identifier];
    } else if (indexPath.section == 2 && editingStyle == UITableViewCellEditingStyleInsert) {
        if (self.activeTabs.count >= 6) {
            [self showLimitMessage:@"Only up to six tabs can be active."];
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
    if (sourceIndexPath.section != 1 || destinationIndexPath.section != 1) {
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
    if (proposedDestinationIndexPath.section != 1) {
        NSInteger row = MAX(0, (NSInteger)self.activeTabs.count - 1);
        return [NSIndexPath indexPathForRow:row inSection:1];
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

- (void)showLimitMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"YTMinimum"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    NSArray *original = %orig;
    NSMutableArray *order = [original mutableCopy];
    if (![order containsObject:@(YTMSettingsCategory)]) {
        NSUInteger anchor = [order indexOfObject:@(1)];
        NSUInteger insertion = anchor == NSNotFound ? order.count : anchor + 1;
        [order insertObject:@(YTMSettingsCategory) atIndex:insertion];
    }
    return order;
}
%end

%hook YTSettingsSectionController
- (void)setSelectedItem:(NSUInteger)selectedItem {
    if (selectedItem != NSNotFound) %orig;
}
%end

%hook YTSettingsSectionItemManager
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category != YTMSettingsCategory) {
        %orig;
        return;
    }

    YTSettingsViewController *settingsController = YTMSafeValueForKey(self, @"_settingsViewControllerDelegate");
    if (!settingsController) return;

    NSArray *items = @[
        [%c(YTSettingsSectionItem) itemWithTitle:@"Feed"
                               titleDescription:@"Ads, Shorts, shelves, and feed cleanup"
                        accessibilityIdentifier:@"YTMinimum.Feed"
                                detailTextBlock:^NSString *{ return @"›"; }
                                    selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
            [settingsController pushViewController:YTMFeedController()];
            return YES;
        }],
        [%c(YTSettingsSectionItem) itemWithTitle:@"Player"
                               titleDescription:@"Playback, colors, fullscreen, and gestures"
                        accessibilityIdentifier:@"YTMinimum.Player"
                                detailTextBlock:^NSString *{ return @"›"; }
                                    selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
            [settingsController pushViewController:YTMPlayerController()];
            return YES;
        }],
        [%c(YTSettingsSectionItem) itemWithTitle:@"Tab bar"
                               titleDescription:@"Startup page and tab visibility"
                        accessibilityIdentifier:@"YTMinimum.TabBar"
                                detailTextBlock:^NSString *{ return @"›"; }
                                    selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
            [settingsController pushViewController:[YTMTabBarController new]];
            return YES;
        }],
        [%c(YTSettingsSectionItem) itemWithTitle:@"Compatibility"
                               titleDescription:[NSString stringWithFormat:@"Designed for YouTube %@. Installed: %@",
                                                 YTMSupportedYouTubeVersion,
                                                 NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"Unknown"]
                        accessibilityIdentifier:@"YTMinimum.Compatibility"
                                detailTextBlock:^NSString *{ return YTMIsSupportedYouTubeVersion() ? @"Ready" : @"Unsupported"; }
                                    selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger index) {
            return YES;
        }],
    ];

    if ([settingsController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        [settingsController setSectionItems:items
                                forCategory:YTMSettingsCategory
                                      title:@"YTMinimum"
                                       icon:nil
                           titleDescription:nil
                               headerHidden:NO];
    } else {
        [settingsController setSectionItems:items
                                forCategory:YTMSettingsCategory
                                      title:@"YTMinimum"
                           titleDescription:nil
                               headerHidden:NO];
    }
}
%end
