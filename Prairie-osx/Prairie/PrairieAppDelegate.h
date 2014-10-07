/*!
    @header
    @brief Declaration of the app's delegate class, connected to the main XIB.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;

#import "PrOverflowingMenu.h"


@interface PrairieAppDelegate : NSObject <NSApplicationDelegate>

// Other public messages
- (id)createBrowser;
/*!
    @brief Add a new window (and matching controller).
    @param window The window whose controller will be added to self.windowControllers. Must not be nil.
    @details This class will watch for a close notification for this window, and remove its controller then.
 */
- (void)registerWindow:(NSWindow *)window;

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

// Other attributes and elements
//! Location of this app's Application Support Directory. Does not check if it actually exists.
@property (nonatomic, readonly, copy) NSURL *  applicationSupportDirectory;

//! Takes the submenu for today's History items and splits it in two for use as Recent History. Public so it can be used for Bindings.
@property (nonatomic, readonly) PrOverflowingMenu *  todayHistoryHandler;
@property (nonatomic, readonly) NSSet *              windowControllers;

@end
