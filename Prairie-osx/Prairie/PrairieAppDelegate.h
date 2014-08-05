/*!
    @header
    @brief Declaration of the app's delegate class, connected to the main XIB.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


// Keys for the preference dictionary
extern NSString * const  PrDefaultPageKey;  // NSString, interpret as URL
extern NSString * const  PrDefaultBackForwardMenuLengthKey;  // NSInteger (probably as NSNumber), must be positive

// Default values of various preferences
extern NSString * const  PrDefaultPage;
extern NSInteger const   PrDefaultBackForwardMenuLength;


@interface PrairieAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, readonly, assign) NSURL *    defaultPage;
@property (nonatomic, readonly, assign) NSInteger  backForwardMenuLength;

@end
