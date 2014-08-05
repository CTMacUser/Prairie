/*!
    @file
    @brief Definition of the app's delegate class, connected to the main XIB.
    @details The application delegate handles app-global setup and data.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrairieAppDelegate.h"


#pragma mark Declared constants

NSString * const  PrDefaultPageKey = @"DefaultPage";
NSString * const  PrDefaultBackForwardMenuLengthKey = @"BackForwardMenuLength";

NSString * const  PrDefaultPage = @"http://www.apple.com";
NSInteger const   PrDefaultBackForwardMenuLength = 10;

@implementation PrairieAppDelegate

#pragma mark Property getters & setters

- (NSURL *)defaultPage
{
    return [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:PrDefaultPageKey]];
}

- (NSInteger)backForwardMenuLength
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:PrDefaultBackForwardMenuLengthKey];
}

#pragma mark Protocol overrides

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Application-level data and setup is usually done in applicationDidFinishLaunching:, but when an app is launched with files to open/print/process (or a blank doc), their handling is done between this and the given method, so anything that the document classes need has to be done here instead.

    // Last-resort preference settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PrDefaultPageKey: PrDefaultPage, PrDefaultBackForwardMenuLengthKey: @(PrDefaultBackForwardMenuLength)}];
}

@end
