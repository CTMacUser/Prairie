/*!
    @header
    @brief Declaration of the app's document controller, connected to the main XIB.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


@interface PrDocumentController : NSDocumentController

/*!
    @brief Action to print a newly-chosen file.
    @param sender The object that sent this message.
    @details The file(s) are chosen from an Open panel, new browser windows are made for each file, a print panel is shown for each window, and each window's web-view is printed (if not cancelled).
 */
- (IBAction)printMore:(id)sender;

//! Filters through file types that can be shown in a WebView.
@property (nonatomic, readonly) id<NSOpenSavePanelDelegate>  openPanelDelegate;

@end
