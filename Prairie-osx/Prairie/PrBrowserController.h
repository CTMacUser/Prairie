/*!
 @header
 @brief Declaration of the controller class for browser windows.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;
@import WebKit;


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

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSTextField *urlDisplay;
@property (weak) IBOutlet NSToolbarItem *toolbarBackForward;
@property (weak) IBOutlet NSTextField *statusLine;
@property (weak) IBOutlet NSLayoutConstraint *bottomSpacing;
@property (weak) IBOutlet NSLayoutConstraint *topSpacing;
@property (weak) IBOutlet NSProgressIndicator *loadingProgress;

@end
