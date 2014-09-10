/*!
    @header
    @brief Declaration of the app's delegate class, connected to the main XIB.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;

#import "PrOverflowingMenu.h"


// Keys for the preference dictionary
//! Preference key for 'defaultPage' (NSURL as NSString, must be valid URL, should be reachable).
extern NSString * const  PrDefaultPageKey;
//! Preference key for 'backForwardMenuLength' (NSInteger as NSNumber, must be positive).
extern NSString * const  PrDefaultBackForwardMenuLengthKey;
//! Preference key for 'controlStatusBarFromWS' (BOOL as NSNumber).
extern NSString * const  PrDefaultControlStatusBarFromWSKey;
//! Preference key for 'openUntitledToDefaultPage' (BOOL as NSNumber).
extern NSString * const  PrDefaultOpenUntitledToDefaultPageKey;
//! Preference key for 'useValidateHistoryMenuItem' (BOOL as NSNumber).
extern NSString * const  PrDefaultUseValidateHistoryMenuItemKey;
//! Preference key for 'loadSaveHistory' (BOOL as NSNumber).
extern NSString * const  PrDefaultLoadSaveHistoryKey;
//! Preference key for 'maxTodayHistoryMenuLength' (NSUInteger as NSNumber).
extern NSString * const  PrDefaultMaxTodayHistoryMenuLengthKey;

@interface PrairieAppDelegate : NSObject <NSApplicationDelegate>

// Other public messages
- (id)createBrowser;

// Actions
- (IBAction)openLocation:(id)sender;
- (IBAction)goHome:(id)sender;
- (IBAction)validateHistory:(id)sender;
- (IBAction)clearHistory:(id)sender;
/*!
    @brief Action to go to a previously-visited page.
    @param sender The object that sent this message.
    @details Called only if there's no browser windows. So create one first, then proceed as normal.
 */
- (IBAction)revisitHistory:(id)sender;

// Outlets
//! The "History" (or "No History") menu item that preceeds today's WebHistory menu items.
@property (weak) IBOutlet NSMenuItem *historyHeader;
//! The "Earlier Today" menu item, preceeding the per-day WebHistory menu items, succeeding the most-recent WebHistory menu items of today, and containing the submenu of the rest of today's WebHistory menu items.
@property (weak) IBOutlet NSMenuItem *earlierToday;

// Preferences
@property (nonatomic, readonly, copy)   NSURL *     defaultPage;
@property (nonatomic, readonly, assign) NSInteger   backForwardMenuLength;
@property (nonatomic, readonly, assign) BOOL        controlStatusBarFromWS;
@property (nonatomic, readonly, assign) BOOL        openUntitledToDefaultPage;
//! Enables the "History" menu item, or keeps it just a header. If enabled, uses the "validateHistory:" action.
@property (nonatomic, readonly, assign) BOOL        useValidateHistoryMenuItem;
//! Whether or not to read the History file on app-launch and/or write it on app-termination.
@property (nonatomic, readonly, assign) BOOL        loadSaveHistory;
//! The maximum number of WebHistory menu items directly below the "History" menu item. Any excess menu items of the same source go in the submenu of the "Earlier Today" menu item.
@property (nonatomic, readonly, assign) NSUInteger  maxTodayHistoryMenuLength;

// Other attributes and elements
//! Location of this app's Application Support Directory. Does not check if it actually exists.
@property (nonatomic, readonly, copy) NSURL *  applicationSupportDirectory;

//! Takes the submenu for today's History items and splits it in two for use as Recent History. Public so it can be used for Bindings.
@property (nonatomic, readonly) PrOverflowingMenu *  todayHistoryHandler;
@property (nonatomic, readonly) NSSet *              windowControllers;

@end
