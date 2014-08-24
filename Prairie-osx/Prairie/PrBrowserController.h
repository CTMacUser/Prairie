/*!
 @header
 @brief Declaration of the controller class for browser windows.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;
@import WebKit;


// Notifications
// The object is the posting PrBrowserController instance. Use the PrBrowserURLKey to get the URL of the referenced resource. Use the PrBrowserLoadFailedWasProvisionalKey to check if the failure happened at the data source's provisional (YES) or committed (NO) stage.
extern NSString * const  PrBrowserLoadFailedNotification;  // The browser failed to load the resource.
extern NSString * const  PrBrowserLoadPassedNotification;  // The browser successfully loaded the resource.
extern NSString * const  PrBrowserPrintFailedNotification;  // The browser failed to print the page.
extern NSString * const  PrBrowserPrintPassedNotification;  // The browser successfully printed the page.

extern NSString * const  PrBrowserURLKey;  // NSURL*
extern NSString * const  PrBrowserLoadFailedWasProvisionalKey;  // BOOL (probably as NSNumber)

// Indices for each part of the toolbarBackForward segmented control
extern NSInteger const PrGoBackSegment;
extern NSInteger const PrGoForwardSegment;


@interface PrBrowserController : NSWindowController

- (IBAction)performBackOrForward:(id)sender;
- (IBAction)toggleLoadingBar:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)openLocation:(id)sender;
- (IBAction)goHome:(id)sender;
- (IBAction)saveDocumentTo:(id)sender;
- (IBAction)printDocument:(id)sender;

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
