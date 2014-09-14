/*!
    @file
    @brief Definition of a preference collection class.
    @details Groups all the various user defaults, including private ones, as properties of a distinct instance.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrUserDefaults.h"


#pragma mark File-local constants

// Keys for the preference dictionary, user-facing entries. Keep values in sync with the entries' keys in resource "UserDefaults.plist". Make sure the entries' values are in sync with what is described here.
//! Preference key for 'defaultPage' (NSURL as NSString, must have valid URL syntax).
static NSString * const  PrDefaultPageKey= @"DefaultPage";
//! Preference key for 'backForwardMenuLength' (NSInteger as NSNumber, must be positive).
static NSString * const  PrDefaultBackForwardMenuLengthKey = @"BackForwardMenuLength";
//! Preference key for 'controlStatusBarFromWS' (BOOL as NSNumber).
static NSString * const  PrDefaultControlStatusBarFromWSKey = @"ControlStatusBarFromWebScripting";
//! Preference key for 'openUntitledToDefaultPage' (BOOL as NSNumber).
static NSString * const  PrDefaultOpenUntitledToDefaultPageKey = @"OpenUntitledToDefaultPage";
//! Preference key for 'useValidateHistoryMenuItem' (BOOL as NSNumber).
static NSString * const  PrDefaultUseValidateHistoryMenuItemKey = @"UseValidateHistoryMenuItem";
//! Preference key for 'loadSaveHistory' (BOOL as NSNumber).
static NSString * const  PrDefaultLoadSaveHistoryKey = @"LoadSaveHistory";
//! Preference key for 'maxTodayHistoryMenuLength' (NSUInteger as NSNumber).
static NSString * const  PrDefaultMaxTodayHistoryMenuLengthKey = @"MaxTodayHistoryMenuLength";

// Keys of the preference dictionary, non-user entries.
//! Preference key for 'historyFileBookmark' (NSData).
static NSString * const  PrDefaultHistoryFileBookmarkKey = @"HistoryFileBookmark";

#pragma mark -

@implementation PrUserDefaults

#pragma mark Factory setup

+ (void)setup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"UserDefaults" withExtension:@"plist"]]];
    });
}

#pragma mark Properties

- (NSURL *)defaultPage {
    return [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:PrDefaultPageKey]];
}

- (NSInteger)backForwardMenuLength {
    return [[NSUserDefaults standardUserDefaults] integerForKey:PrDefaultBackForwardMenuLengthKey];
}

- (BOOL)controlStatusBarFromWS {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultControlStatusBarFromWSKey];
}

- (BOOL)openUntitledToDefaultPage {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultOpenUntitledToDefaultPageKey];
}

- (BOOL)useValidateHistoryMenuItem {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultUseValidateHistoryMenuItemKey];
}

- (BOOL)loadSaveHistory {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultLoadSaveHistoryKey];
}

- (NSUInteger)maxTodayHistoryMenuLength {
    return (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:PrDefaultMaxTodayHistoryMenuLengthKey];
}

- (NSData *)historyFileBookmark {
    return [[NSUserDefaults standardUserDefaults] dataForKey:PrDefaultHistoryFileBookmarkKey];
}

- (void)setHistoryFileBookmark:(NSData *)historyFileBookmark {
    [[NSUserDefaults standardUserDefaults] setObject:historyFileBookmark forKey:PrDefaultHistoryFileBookmarkKey];
}

@end
