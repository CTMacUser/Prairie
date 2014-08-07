/*!
 @file
 @brief Definition of the app's Document class, directly connected to its XIB.
 @details The document encloses a web browser experience.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrDocument.h"
#import "PrairieAppDelegate.h"


#pragma mark Declared constants

NSInteger const PrGoBackSegment    = 0;
NSInteger const PrGoForwardSegment = 1;

#pragma mark File-local constants

static CGFloat const PrStatusBarHeight = 22.0;  // Small; is there a header with the standard sizes?

#pragma mark Private interface

@interface PrDocument ()

- (void)loadPage:(NSURL *)pageURL;
- (void)showError:(NSError *)error;
- (BOOL)showingStatusBar;
- (void)hideStatusBar;
- (void)showStatusBar;

- (void)performPreciseBackOrForward:(id)sender;

@property (nonatomic, readonly) PrairieAppDelegate *appDelegate;

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
        [self performSelector:@selector(loadPage:) withObject:self.appDelegate.defaultPage afterDelay:0.5];
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

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
    if ([anItem action] == @selector(hideShowStatusBar:)) {
        [(id)anItem setState:([self showingStatusBar] ? NSOnState : NSOffState)];
    }
    return [super validateUserInterfaceItem:anItem];
}

#pragma mark WebUIDelegate overrides

// The document object is set as the web-view's UI-delegate within the XIB.

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
    id  newDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];  // Must be YES, no XIB-load (and therefore no webView) otherwise.

    [NSObject cancelPreviousPerformRequestsWithTarget:newDocument selector:@selector(loadPage:) object:self.appDelegate.defaultPage];  // Make sure the argument for "object:" matches what was entered in "windowControllerDidLoadNib:" (by "isEqual:" standards). This can fail if the Home Page preference (quickly) changes between the calls.
    [[newDocument webView].mainFrame loadRequest:request];
    return [newDocument webView];
}

- (void)webViewShow:(WebView *)sender  // UNTESTED
{
    // This method is not generally needed since webView:createWebViewWithRequest: already brings its new window up front. (The implementation can't help it.) But just in case this method is needed without its predecessor....
    [self showWindows];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text
{
    if (self.appDelegate.controlStatusBarFromWS) {
        self.statusLine.stringValue = text;
    }  // Calling the version for "super" for a "else" case caused an internal exception, as in no implementation.
}

- (NSString *)webViewStatusText:(WebView *)sender  // UNTESTED
{
    return self.appDelegate.controlStatusBarFromWS ? self.statusLine.stringValue : [super webViewStatusText:sender];
}

- (BOOL)webViewIsStatusBarVisible:(WebView *)sender  // UNTESTED
{
    return self.appDelegate.controlStatusBarFromWS ? [self showingStatusBar] : [super webViewIsStatusBarVisible:sender];
}

- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible  // UNTESTED
{
    self.appDelegate.controlStatusBarFromWS ? visible ? [self showStatusBar] : [self hideStatusBar] : [super webView:sender setStatusBarVisible:visible];
}

#pragma mark WebFrameLoadDelegate overrides

// The document object is set as the web-view's frame-load-delegate within the XIB.

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {  // Ignore notices from sub-frames.
        [self performSelector:@selector(showError:) withObject:error afterDelay:0.1];
    }
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        sender.window.representedURL = frame.dataSource.initialRequest.URL;
    }
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        sender.window.title = title;
    }
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        [sender.window standardWindowButton:NSWindowDocumentIconButton].image = image;
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        // Some callbacks don't work right for local files; tweaking is required.
        NSURL * const  requestURL = frame.dataSource.initialRequest.URL;

        if ([requestURL isFileURL]) {
            [sender.window standardWindowButton:NSWindowDocumentIconButton].image = [[NSWorkspace sharedWorkspace] iconForFile:[requestURL path]];  // Needed since the file's icon is loaded only once, during webView:didCommitLoadForFrame:, and webView:didReceiveIcon:forFrame: is never called. So during subsequent visits through Back & Forward, the icon from the previously seen page never gets changed out.
        }

        // Enabled/disabled status of the Back and Forward toolbar buttons.
        NSSegmentedControl * const  backForwardControl = (NSSegmentedControl *)self.toolbarBackForward.view;

        [backForwardControl setEnabled:[sender canGoBack] forSegment:PrGoBackSegment];
        [backForwardControl setEnabled:[sender canGoForward] forSegment:PrGoForwardSegment];

        // Revisit menus for the Back and Forward toolbar buttons.
        WebBackForwardList * const  backForwardList = sender.backForwardList;
        NSMenu *                    backMenu = [[NSMenu alloc] initWithTitle:@""];
        NSMenu *                 forwardMenu = [[NSMenu alloc] initWithTitle:@""];
        __block NSInteger         counterTag = 0;
        NSInteger const        maxMenuLength = self.appDelegate.backForwardMenuLength;

        [[backForwardList backListWithLimit:(int)maxMenuLength] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(WebHistoryItem *obj, NSUInteger idx, BOOL *stop){
            NSMenuItem *  backMenuItem = [[NSMenuItem alloc] initWithTitle:obj.title action:@selector(performPreciseBackOrForward:) keyEquivalent:@""];

            backMenuItem.tag = --counterTag;
            backMenuItem.toolTip = obj.originalURLString;
            backMenuItem.target = self;
            [backMenu insertItem:backMenuItem atIndex:-counterTag - 1];
        }];  // The history lists go from earliest to latest. The menus need to go from temporally closest to furthest. The directions are the same for the forward list, but opposing for the back list, so the back list has to be iterated backwards.
        [backForwardControl setMenu:backMenu forSegment:PrGoBackSegment];
        counterTag = 0;
        [[backForwardList forwardListWithLimit:(int)maxMenuLength] enumerateObjectsUsingBlock:^(WebHistoryItem *obj, NSUInteger idx, BOOL *stop){
            NSMenuItem *  forwardMenuItem = [[NSMenuItem alloc] initWithTitle:obj.title action:@selector(performPreciseBackOrForward:) keyEquivalent:@""];

            forwardMenuItem.tag = ++counterTag;
            forwardMenuItem.toolTip = obj.originalURLString;
            forwardMenuItem.target = self;
            [forwardMenu insertItem:forwardMenuItem atIndex:+counterTag - 1];
        }];
        [backForwardControl setMenu:forwardMenu forSegment:PrGoForwardSegment];
    }
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        [self performSelector:@selector(showError:) withObject:error afterDelay:0.1];
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

/*!
    @brief Shows an error as an alert attached to the document window.
    @param error The error to be displayed.
    @details A standard routine to notify the user about a problem. Encapsulating the code means it can be manipulated by selector games (like adding a delay).
 */
- (void)showError:(NSError *)error
{
    [[NSAlert alertWithError:error] beginSheetModalForWindow:self.windowForSheet completionHandler:^void (NSModalResponse returnCode) {
        // Nothing right now.
    }];
}

/*!
    @brief Status Bar visibility status.
    @return YES if the Status Bar is visible, NO otherwise.
 */
- (BOOL)showingStatusBar
{
    return !![self.windowForSheet contentBorderThicknessForEdge:NSMinYEdge];
}

/*!
    @brief Hide the Status Bar.
 */
- (void)hideStatusBar
{
    [self.windowForSheet setContentBorderThickness:(self.bottomSpacing.constant = 0.0) forEdge:NSMinYEdge];
}

/*!
    @brief Show the Status Bar.
 */
- (void)showStatusBar
{
    [self.windowForSheet setContentBorderThickness:(self.bottomSpacing.constant = PrStatusBarHeight) forEdge:NSMinYEdge];
}

/*!
    @brief Getter for "appDelegate" property
    @return The application delegate instance, converted to its actual type.
 */
- (PrairieAppDelegate *)appDelegate
{
    return [NSApp delegate];
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

/*!
    @brief Action to show or hide the Status bar.
    @param sender The object that sent this message.
    @details Checks the hidden/shown status of the Status bar and switches said status (hidden to shown, or shown to hidden).
 */
- (IBAction)hideShowStatusBar:(id)sender
{
    if ([self showingStatusBar]) {
        [self hideStatusBar];
    } else {
        [self showStatusBar];
    }
}

/*!
    @brief Action for menu items within the combined Back/Forward control.
    @param sender The object that sent this message.
    @details Checks which menu item was clicked, and instructs the associated WebView to go to that item's index along its browser history.
 */
- (void)performPreciseBackOrForward:(id)sender
{
    (void)[self.webView goToBackForwardItem:[self.webView.backForwardList itemAtIndex:(int)[sender tag]]];
}


@end
