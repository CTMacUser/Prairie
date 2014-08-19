/*!
    @file
    @brief Definition of the application object's class.
    @details This subclass of NSApplication implements special overrides.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrApplication.h"

@implementation PrApplication

#pragma mark NSUserInterfaceValidations override

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem {
    if ([anItem action] == @selector(runPageLayout:)) {  // NSApplication will not enable menu items that use its (or a subclass') version of this action without explicit validation.
        return YES;
    }
    return [super validateUserInterfaceItem:anItem];
}

@end
