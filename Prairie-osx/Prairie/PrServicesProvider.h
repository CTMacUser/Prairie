/*!
    @header
    @brief Declaration of the Services provider class.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


@interface PrServicesProvider : NSObject

/*!
    @brief Handler for the "Open URL" Service.
    @param pboard Pasteboard for the service data transfers.
    @param userData Custom string to differentiate multiple services using the same handler.
    @param error The error message to log to the console.
    @details Reads the URL from the pasteboard and opens a new browser window starting at that URL.
 */
- (void)openURL:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

@end
