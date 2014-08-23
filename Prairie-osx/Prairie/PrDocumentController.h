/*!
    @header
    @brief Declaration of the app's document controller, connected to the main XIB.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


@interface PrDocumentController : NSDocumentController

@property (nonatomic, readonly) id<NSOpenSavePanelDelegate>  openPanelDelegate;

@end
