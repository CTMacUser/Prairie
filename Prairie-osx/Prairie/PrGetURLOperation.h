/*!
    @header
    @brief Declaration of a URL-displaying operation class.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Foundation;


@interface PrGetURLOperation : NSOperation

+ (instancetype)handleEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply;

@property (readonly, assign) NSAppleEventManagerSuspensionID  eventPair;

@end
