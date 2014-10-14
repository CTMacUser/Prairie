/*!
    @file
    @brief Definition of the Services provider class.
    @details Manages requests from the Services menu.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrServicesProvider.h"
#import "PrairieAppDelegate.h"
#import "PrBrowserController.h"


@implementation PrServicesProvider

// See header for details.
- (void)openURL:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString *__autoreleasing *)error {
    NSUInteger  counter = 0;

    for (NSPasteboardItem *item in pboard.pasteboardItems) {
        NSURL * const  targetURL = [NSURL URLWithString:[item stringForType:[item availableTypeFromArray:@[(__bridge NSString *)kUTTypeURL, (__bridge NSString *)kUTTypeRTF, (__bridge NSString *)kUTTypeUTF8PlainText]]]];

        ++counter;
        if (targetURL) {
            id const  browser = [PrBrowserController createBrowser];
            
            if (browser) {
                [browser showWindow:NSApp];
                [browser loadPage:targetURL title:[item stringForType:@"public.url-name"] searching:nil printing:nil showPrint:NO showProgress:NO];
            } else if (error) {
                *error = [NSString stringWithFormat:NSLocalizedString(@"OPENURL_WINDOW_FAILED", nil), counter, pboard.pasteboardItems.count];
            }
        } else if (error) {
            *error = [NSString stringWithFormat:NSLocalizedString(@"OPENURL_URL_FAILED", nil), counter, pboard.pasteboardItems.count];
        }
    } // Right now, known to work sometimes for UTF-8 text, never for RTF, and unknown for URL and URL-Title.
}

@end
