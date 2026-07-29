// Minimal declarations for the YouTube and AsyncDisplayKit classes YTMinimum
// touches. Signatures follow the public YouTubeHeader project so YTMinimum can
// stay self-contained instead of vendoring that dependency.

#import <UIKit/UIKit.h>

#pragma mark - AsyncDisplayKit

@interface ASDisplayNode : NSObject
@property(atomic, copy, readwrite) NSArray *yogaChildren;
@property(atomic, copy, readwrite) NSString *accessibilityIdentifier;
- (id)controller;
@end

@interface ASCellNode : ASDisplayNode
@end

@interface ASCollectionElement : NSObject
- (ASCellNode *)node;
@end

@interface ASNodeController : NSObject
@property(nonatomic, strong, readwrite) ASDisplayNode *node;
- (NSArray *)children;
@end

@interface ELMComponent : NSObject
- (NSString *)templateURI;
@end

@interface ELMNodeController : ASNodeController
- (ELMComponent *)owningComponent;
@end

@interface _ASCollectionViewCell : UICollectionViewCell
- (id)node;
@end

@interface ASCollectionView : UICollectionView
@end

@interface YTAsyncCollectionView : ASCollectionView
@end

#pragma mark - Settings

@interface YTSettingsCell : UICollectionViewCell
- (void)setSwitchOn:(BOOL)on animated:(BOOL)animated;
@end

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

@interface YTSettingsSectionController : NSObject
- (void)setSelectedItem:(NSUInteger)selectedItem;
@end

@interface YTSettingsSectionItem : NSObject
@property(nonatomic, copy, readwrite) NSString *title;
+ (instancetype)itemWithTitle:(NSString *)title
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              detailTextBlock:(NSString * (^)(void))detailTextBlock
                  selectBlock:(BOOL (^)(YTSettingsCell *cell, NSUInteger index))selectBlock;
+ (instancetype)itemWithTitle:(NSString *)title
             titleDescription:(NSString *)titleDescription
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              detailTextBlock:(NSString * (^)(void))detailTextBlock
                  selectBlock:(BOOL (^)(YTSettingsCell *cell, NSUInteger index))selectBlock;
+ (instancetype)checkmarkItemWithTitle:(NSString *)title
                      titleDescription:(NSString *)titleDescription
                           selectBlock:(BOOL (^)(YTSettingsCell *cell, NSUInteger index))selectBlock;
+ (instancetype)switchItemWithTitle:(NSString *)title
                   titleDescription:(NSString *)titleDescription
            accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           switchOn:(BOOL)switchOn
                        switchBlock:(BOOL (^)(YTSettingsCell *cell, BOOL enabled))switchBlock
                      settingItemId:(int)settingItemId;
@end

@interface YTSettingsViewController : UIViewController
- (void)pushViewController:(UIViewController *)viewController;
- (void)reloadData;
- (void)setSectionItems:(NSMutableArray *)sectionItems
            forCategory:(NSInteger)category
                  title:(NSString *)title
                   icon:(id)icon
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
- (void)setSectionItems:(NSMutableArray *)sectionItems
            forCategory:(NSInteger)category
                  title:(NSString *)title
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
@end

@interface YTSettingsPickerViewController : UIViewController
- (instancetype)initWithNavTitle:(NSString *)navTitle
              pickerSectionTitle:(NSString *)pickerSectionTitle
                            rows:(NSArray *)rows
               selectedItemIndex:(NSUInteger)selectedItemIndex
                 parentResponder:(id)parentResponder;
@end

@interface YTSettingsSectionItemManager : NSObject
- (id)parentResponder;
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry;
@end

#pragma mark - Utilities

@interface YTUIUtils : NSObject
+ (UIViewController *)topViewControllerForPresenting;
+ (BOOL)openURL:(NSURL *)url;
@end

@interface YTToastResponderEvent : NSObject
+ (instancetype)eventWithMessage:(NSString *)message firstResponder:(id)firstResponder;
- (void)send;
@end

@interface YTAlertView : NSObject
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *subtitle;
+ (instancetype)confirmationDialogWithAction:(void (^)(void))action
                                 actionTitle:(NSString *)actionTitle
                                 cancelTitle:(NSString *)cancelTitle;
- (void)show;
@end

@interface YTHeaderContentComboViewController : UIViewController
- (void)refreshPivotBar;
@end
