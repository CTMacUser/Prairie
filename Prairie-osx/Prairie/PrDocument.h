/*!
 @header
 @brief Declaration of the app's Document class, directly connected to its XIB.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;
@import WebKit;

@interface PrDocument : NSDocument

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSTextField *urlDisplay;

@end
