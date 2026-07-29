#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSString *const YTMOfficialYouTubeBundleID = @"com.google.ios.youtube";
static NSString *const YTMOfficialYouTubeName = @"YouTube";

static NSString *YTMAccessGroupIdentifier(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: @"YTMinimum.BundleSeedID",
        (__bridge id)kSecAttrService: @"YTMinimum",
        (__bridge id)kSecReturnAttributes: @YES,
    };

    CFTypeRef rawResult = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &rawResult);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *addQuery = query.mutableCopy;
        addQuery[(__bridge id)kSecValueData] = [NSData data];
        status = SecItemAdd((__bridge CFDictionaryRef)addQuery, &rawResult);
    }

    if (status != errSecSuccess || !rawResult) return nil;
    NSDictionary *attributes = CFBridgingRelease(rawResult);
    return attributes[(__bridge id)kSecAttrAccessGroup];
}

static BOOL YTMIsMainBundle(NSBundle *bundle) {
    return bundle == NSBundle.mainBundle;
}

%group YTMSideloadingHooks

%hook YTVersionUtils
+ (NSString *)appName {
    return YTMOfficialYouTubeName;
}

+ (NSString *)appID {
    return YTMOfficialYouTubeBundleID;
}
%end

%hook GCKBUtils
+ (NSString *)appIdentifier {
    return YTMOfficialYouTubeBundleID;
}
%end

%hook GPCDeviceInfo
+ (NSString *)bundleId {
    return YTMOfficialYouTubeBundleID;
}
%end

%hook OGLBundle
+ (NSString *)shortAppName {
    return YTMOfficialYouTubeName;
}
%end

%hook GVROverlayView
+ (NSString *)appName {
    return YTMOfficialYouTubeName;
}
%end

%hook OGLPhenotypeFlagServiceImpl
- (NSString *)bundleId {
    return YTMOfficialYouTubeBundleID;
}
%end

%hook APMAEU
+ (BOOL)isFAS {
    return YES;
}
%end

%hook GULAppEnvironmentUtil
+ (BOOL)isFromAppStore {
    return YES;
}
%end

%hook SSOConfiguration
- (id)initWithClientID:(id)clientID supportedAccountServices:(id)supportedAccountServices {
    id result = %orig(clientID, supportedAccountServices);
    @try {
        [result setValue:YTMOfficialYouTubeName forKey:@"_shortAppName"];
        [result setValue:YTMOfficialYouTubeBundleID forKey:@"_applicationIdentifier"];
    } @catch (__unused NSException *exception) {
    }
    return result;
}
%end

%hook NSBundle
- (NSString *)bundleIdentifier {
    return YTMIsMainBundle(self) ? YTMOfficialYouTubeBundleID : %orig;
}

- (NSDictionary *)infoDictionary {
    NSDictionary *original = %orig;
    if (!YTMIsMainBundle(self)) return original;

    NSMutableDictionary *info = original.mutableCopy;
    info[@"CFBundleIdentifier"] = YTMOfficialYouTubeBundleID;
    info[@"CFBundleDisplayName"] = YTMOfficialYouTubeName;
    info[@"CFBundleName"] = YTMOfficialYouTubeName;
    return info.copy;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (!YTMIsMainBundle(self)) return %orig(key);
    if ([key isEqualToString:@"CFBundleIdentifier"]) return YTMOfficialYouTubeBundleID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"]) {
        return YTMOfficialYouTubeName;
    }
    return %orig(key);
}
%end

%hook SSOKeychainHelper
+ (NSString *)accessGroup {
    return YTMAccessGroupIdentifier() ?: %orig;
}

+ (NSString *)sharedAccessGroup {
    return YTMAccessGroupIdentifier() ?: %orig;
}
%end

%hook SSOKeychainCore
+ (NSString *)accessGroup {
    return YTMAccessGroupIdentifier() ?: %orig;
}

+ (NSString *)sharedAccessGroup {
    return YTMAccessGroupIdentifier() ?: %orig;
}
%end

%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    if (groupIdentifier.length == 0) return %orig(groupIdentifier);

    NSURL *documents = [[self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *appGroup = [documents URLByAppendingPathComponent:@"YTMinimumAppGroup" isDirectory:YES];
    [self createDirectoryAtURL:appGroup withIntermediateDirectories:YES attributes:nil error:nil];
    return appGroup;
}
%end

%end

%ctor {
    // YTMinimum is intended for injected, sideloaded builds, so this compatibility
    // layer is always enabled. It does not alter the IPA's signed identifier.
    %init(YTMSideloadingHooks);
}

