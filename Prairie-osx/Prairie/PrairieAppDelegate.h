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
extern NSString * const  PrDefaultControlStatusBarFromWSKey;  // BOOL (probably as NSNumber)

// Default values of various preferences
extern NSString * const  PrDefaultPage;
extern NSInteger const   PrDefaultBackForwardMenuLength;
extern BOOL const        PrDefaultControlStatusBarFromWS;


@interface PrairieAppDelegate : NSObject <NSApplicationDelegate, NSOpenSavePanelDelegate>

- (id)createBrowser;

- (IBAction)newDocument:(id)sender;
- (IBAction)openDocument:(id)sender;

- (IBAction)openLocation:(id)sender;
- (IBAction)goHome:(id)sender;

@property (nonatomic, readonly, copy)   NSURL *    defaultPage;
@property (nonatomic, readonly, assign) NSInteger  backForwardMenuLength;
@property (nonatomic, readonly, assign) BOOL       controlStatusBarFromWS;

@property (nonatomic, readonly) NSSet *  windowControllers;

@end
