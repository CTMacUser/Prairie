/*!
    @header
    @brief Declaration of the app's delegate class, connected to the main XIB.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


// Default values of various preferences
extern NSString * const  PrDefaultPage;


@interface PrairieAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, readonly, assign) NSURL *  defaultPage;

@end
