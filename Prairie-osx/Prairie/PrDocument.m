/*!
 @file
 @brief Definition of the app's Document class, directly connected to its XIB.
 @details The document encloses a web browser experience.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrDocument.h"

@implementation PrDocument

#pragma mark Conventional overrides

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
    return NSStringFromClass([self class]);
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    // Load the initial page, either local or a default.
    // (TODO: have the default page be a preference, including a blank page.)
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:(self.fileURL ? self.fileURL : [NSURL URLWithString:@"http://www.apple.com"])]];
    self.fileURL = nil;  // Disconnects file (if any) from infrastructure, treating loaded file as an import.

    // Docs suggest giving a name to group related frames. I'm using a UUID for an easily accessible unique string.
    self.webView.groupName = [[NSUUID UUID] UUIDString];
}

+ (BOOL)autosavesInPlace
{
    return NO;  // viewer-only app
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    WebDataSource * const  source = self.webView.mainFrame.dataSource;
    NSData * const         data = [typeName isEqualToString:(__bridge NSString *)kUTTypeWebArchive] ? source.webArchive.data : source.data;  // Assumes typeName is the actual UTI for current web object when the object isn't a web-archive.

    if ( !data && outError ) {
        *outError = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];  // Is the error code appropriate?
    }
    return data;
    // TODO: currently doesn't work right. Regular saves (and save-as) and reverts seem to be bad ideas. Export seems to work when web-archive is the format, but not public-content. The latter has no extension/type-information to pass on, so the exported file is untyped and useless. Is my assumption on the line for local variable "data" wrong? Should the app switch from Editor to Viewer? (That will require making a subclass of NSDocumentController to open windows correctly.)
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    CFStringRef const  mimeType = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) typeName, kUTTagClassMIMEType);

    if ( mimeType && [WebView canShowMIMEType:(__bridge NSString *) mimeType] ) {
        return YES;
    }
    if ( outError ) {
        NSMutableDictionary *  info = [[NSMutableDictionary alloc] init];

        [info setDictionary:@{NSURLErrorKey: url, NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"NO_MIME_TYPE", @"A notice that the file was not loaded because it is of a MIME type that cannot be handled by WebKit.")}];
        if ( mimeType ) {
            [info setValue:(__bridge NSString *) mimeType forKey:WebKitErrorMIMETypeKey];
        }
        *outError = [NSError errorWithDomain:WebKitErrorDomain code:WebKitErrorCannotShowURL userInfo:info];
    }
    return NO;  // Cannot proceed if WebView can't process the required MIME type.
}

- (BOOL)isEntireFileLoaded
{
    // The file is loaded when the WebView finishes with it.
    return self.webView && !self.webView.isLoading;
}

#pragma mark WebUIDelegate overrides

// The document object is set as the web-view's UI-delegate within the XIB.

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
    id  newDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];

    [[newDocument webView].mainFrame loadRequest:request];
    return [newDocument webView];
}

@end
