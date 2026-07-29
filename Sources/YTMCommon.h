#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT NSString *const YTMDefaultsSuite;
FOUNDATION_EXPORT NSString *const YTMSupportedYouTubeVersion;
FOUNDATION_EXPORT NSString *YTMCurrentPivotIdentifier;

NSUserDefaults *YTMDefaults(void);
BOOL YTMBool(NSString *key);
NSInteger YTMInteger(NSString *key);
NSString *YTMString(NSString *key);
NSArray<NSString *> *YTMStringArray(NSString *key);
void YTMSetBool(NSString *key, BOOL value);
void YTMSetInteger(NSString *key, NSInteger value);
void YTMSetObject(NSString *key, id _Nullable value);

UIColor *YTMColor(NSString *key);
NSString *YTMHexStringFromColor(UIColor *color);

BOOL YTMIsSupportedYouTubeVersion(void);
id _Nullable YTMSafeValueForKey(id object, NSString *key);
BOOL YTMDescriptionContainsAny(id object, NSArray<NSString *> *tokens);

NSArray<NSString *> *YTMDefaultActiveTabs(void);
NSArray<NSString *> *YTMDefaultInactiveTabs(void);
NSString *YTMTitleForPivotIdentifier(NSString *identifier);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
