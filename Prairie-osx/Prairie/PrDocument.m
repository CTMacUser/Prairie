/*!
 @file
 @brief Definition of the app's Document class, directly connected to its XIB.
 @details The document encloses a web browser experience.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrDocument.h"


#pragma mark Declared constants

NSInteger const PrGoBackSegment    = 0;
NSInteger const PrGoForwardSegment = 1;

#pragma mark Private interface

@interface PrDocument ()

- (void)loadPage:(NSURL *)pageURL;

@end

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

    // Load the initial page,...
    if ( self.fileURL ) {
        // ...local ones immediately.
        [self loadPage:self.fileURL];
        self.fileURL = nil;  // Disconnects file from document control, treating it like an import.
    } else {
        // ...remote ones after a delay. The gap allows a document that'll be opened from another with a starting link time to cancel the home-page load and insert the starting link as its first one.
        [self performSelector:@selector(loadPage:) withObject:[NSURL URLWithString:@"http://www.apple.com"] afterDelay:0.5];

        // TODO: have the default page be a preference, including a blank page. There will be a risk that the preference could change between the delay call and the cancel call, meaning the cancel wouldn't happen and both the home page and the starting-link page will be tried.
    }

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

    [NSObject cancelPreviousPerformRequestsWithTarget:newDocument selector:@selector(loadPage:) object:[NSURL URLWithString:@"http://www.apple.com"]];  // make sure the argument for "object:" matches what was entered in "windowControllerDidLoadNib:" (by "isEqual:" standards).
    [[newDocument webView].mainFrame loadRequest:request];
    return [newDocument webView];
}

#pragma mark WebFrameLoadDelegate overrides

// The document object is set as the web-view's frame-load-delegate within the XIB.

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame]) {  // Ignore notices from sub-frames.
        sender.window.title = title;
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame]) {  // Ignore notices from sub-frames.
        [(NSSegmentedControl *)self.toolbarBackForward.view setEnabled:[sender canGoBack] forSegment:PrGoBackSegment];
        [(NSSegmentedControl *)self.toolbarBackForward.view setEnabled:[sender canGoForward] forSegment:PrGoForwardSegment];
    }
}

#pragma mark Private methods

/*!
    @brief Orders web-view member to load a new URL.
    @param pageURL The URL for the resource to be loaded.
    @details Encapsulates URL loads, packaging the URL into the NSURLRequest object that loadRequest needs. Having this code encapsulated means it can be manipulated by selector games (like adding a delay).
 */
- (void)loadPage:(NSURL *)pageURL
{
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:pageURL]];
}

#pragma mark Action methods

/*!
    @brief Action for the combined Back/Forward control.
    @param sender The object that sent this message.
    @details Checks which segment was clicked, and instructs the associated WebView to go back or forward one step along its browser history.
 */
- (IBAction)performBackOrForward:(id)sender
{
    switch ([sender selectedSegment]) {
        case PrGoBackSegment:
            (void)[self.webView goBack];
            break;
            
        case PrGoForwardSegment:
            (void)[self.webView goForward];
            break;
            
        default:
            break;
    }
}

@end
