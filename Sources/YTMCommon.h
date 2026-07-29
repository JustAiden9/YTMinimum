#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT NSString *const YTMDefaultsSuite;
FOUNDATION_EXPORT NSString *const YTMSupportedYouTubeVersion;
// Element sizing runs on background threads, so the active tab is tracked as a
// plain flag instead of a shared string that the main thread could replace mid
// comparison.
void YTMSetCurrentPivotIdentifier(NSString *_Nullable identifier);
BOOL YTMCurrentPivotIsSubscriptions(void);

NSUserDefaults *YTMDefaults(void);
BOOL YTMBool(NSString *key);
NSInteger YTMInteger(NSString *key);
NSString *YTMString(NSString *key);
NSArray<NSString *> *YTMStringArray(NSString *key);
void YTMSetBool(NSString *key, BOOL value);
void YTMSetInteger(NSString *key, NSInteger value);
void YTMSetObject(NSString *key, id _Nullable value);
void YTMResetSettings(void);

// Bumped on every write so cached decisions can tell that a toggle changed.
uint64_t YTMSettingsGeneration(void);

UIColor *YTMColor(NSString *key);
NSString *YTMHexStringFromColor(UIColor *color);

BOOL YTMIsSupportedYouTubeVersion(void);
NSString *YTMInstalledYouTubeVersion(void);
id _Nullable YTMSafeValueForKey(id object, NSString *key);
BOOL YTMDescriptionContainsAny(id object, NSArray<NSString *> *tokens);

NSArray<NSString *> *YTMDefaultActiveTabs(void);
NSArray<NSString *> *YTMDefaultInactiveTabs(void);
NSString *YTMTitleForPivotIdentifier(NSString *identifier);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
