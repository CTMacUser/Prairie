/*!
    @header
    @brief Declaration of the controller class for source-view windows.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;
@import WebKit;


//! Controller class for source-view windows.
@interface PrSourceViewController : NSWindowController <NSWindowDelegate>

// Factory methods
/*!
    @brief Creates a source-view window, with a matching controller of this type, and initialized data.
    @param source The source data, including text. Must not be NIL.
    @details Registers the window (controller) with the application delegate.
    @return The window controller of the new window, NIL if something went wrong.
 */
+ (instancetype)createViewerOfSource:(WebDataSource *)source;

// Actions
/*!
    @brief Action to print the currently displayed source text.
    @param sender The object that sent this message.
 */
- (IBAction)printDocument:(id)sender;

// Outlets
//! The primary control of the window, containing the text-view.
@property (weak) IBOutlet NSScrollView *scrollView;
//! The business control of the window; contains the source text.
@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end
