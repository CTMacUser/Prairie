/*!
    @file
    @brief Definition of the app's delegate class, connected to the main XIB.
    @details The application delegate handles app-global setup and data.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrairieAppDelegate.h"
#import "PrDocument.h"


#pragma mark Declared constants

NSString * const  PrDefaultPageKey = @"DefaultPage";
NSString * const  PrDefaultBackForwardMenuLengthKey = @"BackForwardMenuLength";
NSString * const  PrDefaultControlStatusBarFromWSKey = @"ControlStatusBarFromWebScripting";

NSString * const  PrDefaultPage = @"http://www.apple.com";
NSInteger const   PrDefaultBackForwardMenuLength = 10;
BOOL const        PrDefaultControlStatusBarFromWS = NO;

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

- (BOOL)controlStatusBarFromWS
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultControlStatusBarFromWSKey];
}

#pragma mark Protocol overrides

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Application-level data and setup is usually done in applicationDidFinishLaunching:, but when an app is launched with files to open/print/process (or a blank doc), their handling is done between this and the given method, so anything that the document classes need has to be done here instead.

    // Last-resort preference settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PrDefaultPageKey: PrDefaultPage, PrDefaultBackForwardMenuLengthKey: @(PrDefaultBackForwardMenuLength), PrDefaultControlStatusBarFromWSKey: @(PrDefaultControlStatusBarFromWS)}];
}

#pragma mark Action methods

/*!
    @brief Action to start entering an URL for browsing.
    @param sender The object that sent this message.
    @details Called only if there's no browser windows. So create one first, then proceed as normal.
 */
- (IBAction)openLocation:(id)sender
{
    return [[PrDocument createPagelessDocument] openLocation:sender];
}

/*!
    @brief Action to visit the designated home page.
    @param sender The object that sent this message.
    @details Called only if there's no browser windows. So create one first, then proceed as normal.
 */
- (IBAction)goHome:(id)sender
{
    return [[PrDocument createPagelessDocument] goHome:sender];
}

@end
