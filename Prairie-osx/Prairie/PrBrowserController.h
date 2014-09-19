/*!
 @header
 @brief Declaration of the controller class for browser windows.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;
@import WebKit;


// Notifications
// The object is the posting PrBrowserController instance. Use the PrBrowserURLKey to get the URL of the referenced resource. Use the PrBrowserLoadFailedWasProvisionalKey to check if the failure happened at the data source's provisional (YES) or committed (NO) stage. Use the PrBrowserErrorKey to check the actual error encountered.
extern NSString * const  PrBrowserLoadFailedNotification;  // The browser failed to load the resource.
extern NSString * const  PrBrowserLoadPassedNotification;  // The browser successfully loaded the resource.
extern NSString * const  PrBrowserPrintFailedNotification;  // The browser failed to print the page.
extern NSString * const  PrBrowserPrintPassedNotification;  // The browser successfully printed the page.

extern NSString * const  PrBrowserURLKey;  // NSURL*
extern NSString * const  PrBrowserLoadFailedWasProvisionalKey;  // BOOL (probably as NSNumber)
extern NSString * const  PrBrowserErrorKey;  // NSError*

// Indices for each part of the toolbarBackForward segmented control
extern NSInteger const PrGoBackSegment;
extern NSInteger const PrGoForwardSegment;


@interface PrBrowserController : NSWindowController <NSWindowDelegate>

- (IBAction)performBackOrForward:(id)sender;
- (IBAction)toggleLoadingBar:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)openLocation:(id)sender;
- (IBAction)goHome:(id)sender;
- (IBAction)saveDocumentTo:(id)sender;
- (IBAction)printDocument:(id)sender;
/*!
    @brief Action to go to a previously-visited page.
    @param sender The object that sent this message.
    @details Triggers the corresponding menu item's WebHistoryItem to be visited.
 */
- (IBAction)revisitHistory:(id)sender;

/*!
    @brief Loads a new URL and possibly applies additional actions.
    @param pageURL The URL for the resource to be loaded.
    @param pageTitle The title applied to the window once the resource is loaded. May be nil.
    @param search The text to search for once the resource is loaded. May be nil.
    @param info The parameters to print from once the resource is loaded. May be nil.
    @param configure Whether to show print panel once the resource is loaded. Ignored if info is nil.
    @param progress Whether to show progress while printing once the resource is loaded. Ignored if info is nil.
    @details Encapsulates URL loads, packaging the URL into the NSURLRequest object that the loadRequest call needs. If the page is successfully loaded, may perform the following actions. If search is not nil, its first occurrence in the page text is highlighted. If info is not nil, it is used as the configuration settings while the page is printed.

    Will send either a PrBrowserLoadFailedNotification or PrBrowserLoadPassedNotification when the page loading ends. The notification object is this window controller instance. The user dictionary has entries with the desired URL and, if the load failed, a Boolean indicating if the load ended during the provisional or committed phase. If printing is enabled, a notification from printWithInfo:showPrint:showProgress: is also sent.
 */
- (void)loadPage:(NSURL *)pageURL title:(NSString *)pageTitle searching:(NSString *)search printing:(NSPrintInfo *)info showPrint:(BOOL)configure showProgress:(BOOL)progress;
- (void)loadPage:(NSURL *)pageURL;
- (void)printWithInfo:(NSPrintInfo *)info showPrint:(BOOL)configure showProgress:(BOOL)progress;

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSTextField *urlDisplay;
@property (weak) IBOutlet NSToolbarItem *toolbarBackForward;
@property (weak) IBOutlet NSTextField *statusLine;
@property (weak) IBOutlet NSLayoutConstraint *bottomSpacing;
@property (weak) IBOutlet NSLayoutConstraint *topSpacing;
@property (weak) IBOutlet NSProgressIndicator *loadingProgress;

@end
