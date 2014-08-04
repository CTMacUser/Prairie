/*!
    @file
    @brief Definition of the app's delegate class, connected to the main XIB.
    @details The application delegate handle app-global setup and data.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrairieAppDelegate.h"


#pragma mark Declared constants

NSString * const  PrDefaultPage = @"http://www.apple.com";

@implementation PrairieAppDelegate

#pragma mark Property getters & setters

- (NSURL *)defaultPage
{
    return [NSURL URLWithString:PrDefaultPage];
}

@end
