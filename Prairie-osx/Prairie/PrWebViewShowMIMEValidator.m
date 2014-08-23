/*!
    @file
    @brief Definition of an open-panel filter.
    @details A validator that determines the MIME type of a file, and passes the file if its MIME type can be displayed by a WebView control. Since the process may take a while (relatively) and involve NSError objects, the -panel:validateURL:error: method was preferred over -panel:shouldEnableURL:. But that spiritual similarity means that this delegate should not be used for save-panels.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrWebViewShowMIMEValidator.h"

@import WebKit;


@implementation PrWebViewShowMIMEValidator

#pragma mark NSOpenSavePanelDelegate overrides

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError *__autoreleasing *)outError {
    id  utiType;
    
    if ([url getResourceValue:&utiType forKey:NSURLTypeIdentifierKey error:outError]) {
        NSString * const  mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)(NSString *)utiType, kUTTagClassMIMEType);
        
        if (mimeType) {
            return [WebView canShowMIMEType:mimeType];
        }
        if ( outError ) {
            *outError = [NSError errorWithDomain:WebKitErrorDomain code:WebKitErrorCannotShowMIMEType userInfo:@{NSURLErrorKey: url, WebKitErrorMIMETypeKey: [NSNull null], NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"NO_MIME_TYPE", nil)}];
        }
    }
    return NO;
}

@end
