/*!
 @header
 @brief Declaration of the app's Document class, directly connected to its XIB.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;
@import WebKit;


// Indices for each part of the toolbarBackForward segmented control
extern NSInteger const PrGoBackSegment;
extern NSInteger const PrGoForwardSegment;


@interface PrDocument : NSDocument

- (IBAction)performBackOrForward:(id)sender;

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSTextField *urlDisplay;
@property (weak) IBOutlet NSToolbarItem *toolbarBackForward;

@end
