/*!
    @header
    @brief Declaration of the app's delegate class, connected to the main XIB.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


// Keys for the preference dictionary
extern NSString * const  PrDefaultPageKey;  // NSString, interpret as URL
extern NSString * const  PrDefaultBackForwardMenuLengthKey;  // NSInteger (probably as NSNumber), must be positive
extern NSString * const  PrDefaultControlStatusBarFromWSKey;  // BOOL (probably as NSNumber)
extern NSString * const  PrDefaultOpenUntitledToDefaultPageKey;  // BOOL (probably as NSNumber)
//! Preference key for "useValidateHistoryMenuItem".
extern NSString * const  PrDefaultUseValidateHistoryMenuItemKey;
//! Preference key for "loadSaveHistory".
extern NSString * const  PrDefaultLoadSaveHistoryKey;

// Default values of various preferences
extern NSString * const  PrDefaultPage;
extern NSInteger const   PrDefaultBackForwardMenuLength;
extern BOOL const        PrDefaultControlStatusBarFromWS;
extern BOOL const        PrDefaultOpenUntitledToDefaultPage;
//! Default value for "useValidateHistoryMenuItem".
extern BOOL const        PrDefaultUseValidateHistoryMenuItem;
//! Default value for "loadSaveHistory".
extern BOOL const        PrDefaultLoadSaveHistory;


@interface PrairieAppDelegate : NSObject <NSApplicationDelegate>

- (id)createBrowser;

- (IBAction)openLocation:(id)sender;
- (IBAction)goHome:(id)sender;
- (IBAction)validateHistory:(id)sender;
- (IBAction)clearHistory:(id)sender;

// Preferences
@property (nonatomic, readonly, copy)   NSURL *    defaultPage;
@property (nonatomic, readonly, assign) NSInteger  backForwardMenuLength;
@property (nonatomic, readonly, assign) BOOL       controlStatusBarFromWS;
@property (nonatomic, readonly, assign) BOOL       openUntitledToDefaultPage;
//! Enables the "History" menu item, or keeps it just a header. If enabled, uses the "validateHistory:" action.
@property (nonatomic, readonly, assign) BOOL       useValidateHistoryMenuItem;
//! Whether or not to read the History file on app-launch and/or write it on app-termination.
@property (nonatomic, readonly, assign) BOOL       loadSaveHistory;

//! Location of this app's Application Support Directory. Does not check if it actually exists.
@property (nonatomic, readonly, copy) NSURL *  applicationSupportDirectory;

@property (nonatomic, readonly) NSSet *  windowControllers;

@end
