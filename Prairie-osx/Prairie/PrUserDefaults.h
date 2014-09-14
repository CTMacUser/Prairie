/*!
    @header
    @brief Declaration of a preference collection class.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Foundation;


@interface PrUserDefaults : NSObject

/*!
    @brief Singleton access.
    @details Since the property data is global, might as well use a global instance for access.
    @return The singleton. Pray that it doesn't fail (and return nil).
 */
+ (instancetype)sharedInstance;

/*!
    @brief Connect to the NSUserDefaults system.
    @details Loads the contents of the user-default resource file as the app's Registration-domain user defaults. Call this during application initialization. Since the effects are global, so are the properties and all instances are effectively the same.
 */
+ (void)setup;

// User-facing Preferences
//! Resource to load for Home Page requests. Has entry in User-Defaults file.
@property (nonatomic, readonly, copy)   NSURL *     defaultPage;
//! Maximum number of items for the menus on the Back and Forward browser window toolbar buttons. Has entry in User-Defaults file.
@property (nonatomic, readonly, assign) NSInteger   backForwardMenuLength;
//! Enables inspection and control of a browser window's status bar and the text within. Has entry in User-Defaults file.
@property (nonatomic, readonly, assign) BOOL        controlStatusBarFromWS;
//! Whether or not new browser windows start by loading the Home Page, opposed to a blank frame with the URL entry field selected. Has entry in User-Defaults file.
@property (nonatomic, readonly, assign) BOOL        openUntitledToDefaultPage;
//! Enables the "History" menu item, or keeps it just a header. If enabled, uses the "validateHistory:" action. Has entry in User-Defaults file.
@property (nonatomic, readonly, assign) BOOL        useValidateHistoryMenuItem;
//! Whether or not to read the History file on app-launch and/or write it on app-termination. Has entry in User-Defaults file.
@property (nonatomic, readonly, assign) BOOL        loadSaveHistory;
//! The maximum number of WebHistory menu items directly below the "History" menu item. Any excess menu items of the same source go in the submenu of the "Earlier Today" menu item. Has entry in User-Defaults file.
@property (nonatomic, readonly, assign) NSUInteger  maxTodayHistoryMenuLength;

// Non-user (i.e. private) Preferences
//! Bookmark for the History file. Starts as nil; valid when the WebHistory store gets saved at least once.
@property (nonatomic) NSData *  historyFileBookmark;

@end
