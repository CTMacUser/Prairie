/*!
 @file
 @brief Definition of the controller class for browser windows.
 @details The document encloses a web browser experience.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrBrowserController.h"
#import "PrairieAppDelegate.h"


#pragma mark Declared constants

NSInteger const PrGoBackSegment    = 0;
NSInteger const PrGoForwardSegment = 1;

#pragma mark File-local constants

static CGFloat const PrLoadingBarHeight = 32.0;  // Regular; is there a header with the standard sizes?
static CGFloat const PrStatusBarHeight  = 22.0;  // Small

#pragma mark Private interface

@interface PrBrowserController ()

- (void)notifyOnProgressStarted:(NSNotification *)notification;
- (void)notifyOnProgressChanged:(NSNotification *)notification;
- (void)notifyOnProgressFinished:(NSNotification *)notification;

- (void)showError:(NSError *)error;
- (BOOL)isLoadingBarVisible;
- (void)hideLoadingBar;
- (void)showLoadingBar;
- (BOOL)isStatusBarVisible;
- (void)hideStatusBar;
- (void)showStatusBar;

- (void)performPreciseBackOrForward:(id)sender;

@property (nonatomic, readonly) PrairieAppDelegate *appDelegate;

@end

@implementation PrBrowserController

#pragma mark Conventional overrides

- (id)init
{
    self = [super initWithWindowNibName:[NSStringFromClass([self class]) stringByReplacingOccurrencesOfString:@"Controller" withString:@""]];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Observe notifications for web page loading progress.
    NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

    [notifier addObserver:self selector:@selector(notifyOnProgressStarted:) name:WebViewProgressStartedNotification object:self.webView];
    [notifier addObserver:self selector:@selector(notifyOnProgressChanged:) name:WebViewProgressEstimateChangedNotification object:self.webView];
    [notifier addObserver:self selector:@selector(notifyOnProgressFinished:) name:WebViewProgressFinishedNotification object:self.webView];

    // Docs suggest giving a name to group related frames. I'm using a UUID for an easily accessible unique string.
    self.webView.groupName = [[NSUUID UUID] UUIDString];
}

#pragma mark NSMenuValidation override

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL const  action = [menuItem action];

    if (action == @selector(toggleStatusBar:)) {
        menuItem.title = [self isStatusBarVisible] ? NSLocalizedString(@"HIDE_STATUS_BAR", nil) : NSLocalizedString(@"SHOW_STATUS_BAR", nil);
    } else if (action == @selector(toggleLoadingBar:)) {
        menuItem.title = [self isLoadingBarVisible] ? NSLocalizedString(@"HIDE_LOADING_BAR", nil) : NSLocalizedString(@"SHOW_LOADING_BAR", nil);
    } else if (action == @selector(saveDocumentTo:)) {
        if (!self.webView.mainFrame.dataSource.data) {  // Also triggers when dataSource is nil.
            return NO;
        }
    }
    return YES;
}

#pragma mark WebUIDelegate overrides

// The document object is set as the web-view's UI-delegate within the XIB.

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
    id const  browser = [self.appDelegate createBrowser];

    [[browser webView].mainFrame loadRequest:request];
    return [browser webView];
}

- (void)webViewShow:(WebView *)sender
{
    [self showWindow:nil];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text
{
    if (self.appDelegate.controlStatusBarFromWS) {
        self.statusLine.stringValue = text;
    }  // Calling the version for "super" for an "else" case caused an internal exception, as in no implementation.
}

- (NSString *)webViewStatusText:(WebView *)sender  // UNTESTED
{
    return self.appDelegate.controlStatusBarFromWS ? self.statusLine.stringValue : [super webViewStatusText:sender];
}

- (BOOL)webViewAreToolbarsVisible:(WebView *)sender  // UNTESTED
{
    // TODO: add preference control to block these two methods (ControlToolbarsFromWS)
    return [sender.window.toolbar isVisible] || [self isLoadingBarVisible];
}

- (void)webView:(WebView *)sender setToolbarsVisible:(BOOL)visible  // UNTESTED
{
    [sender.window.toolbar setVisible:visible];
    visible ? [self showLoadingBar] : [self hideLoadingBar];
}

- (BOOL)webViewIsStatusBarVisible:(WebView *)sender  // UNTESTED
{
    return self.appDelegate.controlStatusBarFromWS ? [self isStatusBarVisible] : [super webViewIsStatusBarVisible:sender];
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
        self.urlDisplay.stringValue = sender.mainFrameURL;
        if ([sender acceptsFirstResponder]) {
            (void)[self.window makeFirstResponder:sender];
        }

        // Some callbacks don't work right for local files; tweaking is required.
        NSURL * const  requestURL = frame.dataSource.initialRequest.URL;

        if ([requestURL isFileURL]) {
            [sender.window standardWindowButton:NSWindowDocumentIconButton].image = [[NSWorkspace sharedWorkspace] iconForFile:[requestURL path]];  // Needed since the file's icon is loaded only once, during webView:didCommitLoadForFrame:, and webView:didReceiveIcon:forFrame: is never called. So during subsequent visits through Back & Forward, the icon from the previously seen page never gets changed out.
        }
        if (!frame.dataSource.pageTitle) {
            sender.window.title = requestURL.lastPathComponent;
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
            NSString *  itemTitle = obj.title;

            if (!itemTitle) {
                // Some (file) URLs don't generate a WebView-compatible title.
                itemTitle = [[NSURL URLWithString:obj.URLString] lastPathComponent];
            }

            NSMenuItem *  backMenuItem = [[NSMenuItem alloc] initWithTitle:itemTitle action:@selector(performPreciseBackOrForward:) keyEquivalent:@""];

            backMenuItem.tag = --counterTag;
            backMenuItem.toolTip = obj.originalURLString;
            backMenuItem.target = self;
            [backMenu insertItem:backMenuItem atIndex:-counterTag - 1];
        }];  // The history lists go from earliest to latest. The menus need to go from temporally closest to furthest. The directions are the same for the forward list, but opposing for the back list, so the back list has to be iterated backwards.
        [backForwardControl setMenu:backMenu forSegment:PrGoBackSegment];
        counterTag = 0;
        [[backForwardList forwardListWithLimit:(int)maxMenuLength] enumerateObjectsUsingBlock:^(WebHistoryItem *obj, NSUInteger idx, BOOL *stop){
            NSString *  itemTitle = obj.title;
            
            if (!itemTitle) {
                // Some (file) URLs don't generate a WebView-compatible title.
                itemTitle = [[NSURL URLWithString:obj.URLString] lastPathComponent];
            }
            
            NSMenuItem *  forwardMenuItem = [[NSMenuItem alloc] initWithTitle:itemTitle action:@selector(performPreciseBackOrForward:) keyEquivalent:@""];

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

#pragma mark Notifications

/*!
    @brief Response to WebViewProgressStartedNotification.
    @param notification The sent notification.
    @details Updates the UI to acknowledge a download by starting the progress bar (if visible).
 */
- (void)notifyOnProgressStarted:(NSNotification *)notification
{
    self.loadingProgress.style = NSProgressIndicatorBarStyle;
    [self.loadingProgress startAnimation:nil];
}

/*!
    @brief Response to WebViewProgressEstimateChangedNotification.
    @param notification The sent notification.
    @details Updates the UI to acknowledge an in-progress download by updating the progress bar (if visible).
 */
- (void)notifyOnProgressChanged:(NSNotification *)notification
{
    [self.loadingProgress setIndeterminate:NO];
    [self.loadingProgress setDoubleValue:self.webView.estimatedProgress];
}

/*!
    @brief Response to WebViewProgressFinishedNotification.
    @param notification The sent notification.
    @details Updates the UI to acknowledge a completed download by stopping the progress bar (if visible).
 */
- (void)notifyOnProgressFinished:(NSNotification *)notification
{
    [self.loadingProgress stopAnimation:nil];
    self.loadingProgress.style = NSProgressIndicatorSpinningStyle;  // Workaround a long-standing bug where a bar-style progress bar set to auto-disappear doesn't actually do that when the animation stops.
    [self.loadingProgress setIndeterminate:YES];
}

#pragma mark Public methods (besides actions)

/*!
    @brief Orders web-view member to load a new URL.
    @param pageURL The URL for the resource to be loaded.
    @details Encapsulates URL loads, packaging the URL into the NSURLRequest object that loadRequest needs. Having this code encapsulated means it can be manipulated by selector games (like adding a delay).
 */
- (void)loadPage:(NSURL *)pageURL
{
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:pageURL]];
}

#pragma mark Private methods

/*!
    @brief Shows an error as an alert attached to the document window.
    @param error The error to be displayed.
    @details A standard routine to notify the user about a problem. Encapsulating the code means it can be manipulated by selector games (like adding a delay).
 */
- (void)showError:(NSError *)error
{
    [[NSAlert alertWithError:error] beginSheetModalForWindow:self.window completionHandler:^void (NSModalResponse returnCode) {
        // Nothing right now.
    }];
}

/*!
    @brief Loading Bar visibility status.
    @return YES if the Loading Bar is visible, NO otherwise.
 */
- (BOOL)isLoadingBarVisible
{
    return !![self.window contentBorderThicknessForEdge:NSMaxYEdge];
}

/*!
    @brief Hide the Loading Bar.
 */
- (void)hideLoadingBar
{
    [self.window setContentBorderThickness:(self.topSpacing.constant = 0.0) forEdge:NSMaxYEdge];
    [self.urlDisplay setHidden:YES];
    [self.loadingProgress setHidden:YES];
}

/*!
    @brief Show the Loading Bar.
 */
- (void)showLoadingBar
{
    [self.loadingProgress setHidden:NO];
    [self.urlDisplay setHidden:NO];
    [self.window setContentBorderThickness:(self.topSpacing.constant = PrLoadingBarHeight) forEdge:NSMaxYEdge];
}

/*!
    @brief Status Bar visibility status.
    @return YES if the Status Bar is visible, NO otherwise.
 */
- (BOOL)isStatusBarVisible
{
    return !![self.window contentBorderThicknessForEdge:NSMinYEdge];
}

/*!
    @brief Hide the Status Bar.
 */
- (void)hideStatusBar
{
    [self.window setContentBorderThickness:(self.bottomSpacing.constant = 0.0) forEdge:NSMinYEdge];
    [self.statusLine setHidden:YES];
}

/*!
    @brief Show the Status Bar.
 */
- (void)showStatusBar
{
    [self.statusLine setHidden:NO];
    [self.window setContentBorderThickness:(self.bottomSpacing.constant = PrStatusBarHeight) forEdge:NSMinYEdge];
}

#pragma mark Property getters & setters

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
    @brief Action to show or hide the Loading bar.
    @param sender The object that sent this message.
    @details Checks the hidden/shown status of the Loading bar (with the URL text and loading-progress controls) and switches said status (hidden to shown, or shown to hidden).
 */
- (IBAction)toggleLoadingBar:(id)sender
{
    if ([self isLoadingBarVisible]) {
        [self hideLoadingBar];
    } else {
        [self showLoadingBar];
    }
}

/*!
    @brief Action to show or hide the Status bar.
    @param sender The object that sent this message.
    @details Checks the hidden/shown status of the Status bar and switches said status (hidden to shown, or shown to hidden).
 */
- (IBAction)toggleStatusBar:(id)sender
{
    if ([self isStatusBarVisible]) {
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

/*!
    @brief Action to open a (file) URL as the next page for this browser window.
    @param sender The object that sent this message.
 */
- (IBAction)openDocument:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]] && [sender tag]) {
        // Have the "Open in New Window…" command instead of the regular "Open…" one. Just do what would happen if this class didn't intercept openDocument:.
        return [self.appDelegate openDocument:sender];
    }

    NSOpenPanel * const  panel = [NSOpenPanel openPanel];

    panel.delegate = self.appDelegate;  // This action has the same filtering criteria that the app-delegate's version has, so reuse the panel-delegate, which happens to be the app-delegate itself.
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        switch (result) {
            case NSFileHandlingPanelOKButton:
                [self loadPage:panel.URLs.firstObject];
                break;
                
            default:
                break;
        }
    }];  // This time, don't turn on multiple files, since there's only one presentation surface.
}

/*!
    @brief Action to save a copy of the currently displayed resource.
    @param sender The object that sent this message.
 */
- (IBAction)saveDocumentTo:(id)sender
{
    NSSavePanel * const       panel = [NSSavePanel savePanel];
    WebDataSource * const    source = self.webView.mainFrame.dataSource;
    NSURLResponse * const  response = source.response;
    NSArray * const       fileTypes = (__bridge_transfer NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassMIMEType, (__bridge CFStringRef)response.MIMEType, NULL);

    panel.allowedFileTypes = [fileTypes arrayByAddingObject:(__bridge NSString *)kUTTypeWebArchive];
    panel.nameFieldStringValue = response.suggestedFilename;
    panel.canSelectHiddenExtension = YES;

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSError  *error = nil;

            if (![([fileTypes firstObjectCommonWithArray:(__bridge_transfer NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)panel.URL.pathExtension, NULL)] ? source.data : source.webArchive.data) writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) {
                [self performSelector:@selector(showError:) withObject:error afterDelay:0.0];
            }
        }
    }];
}

/*!
    @brief Action to start entering an URL for browsing.
    @param sender The object that sent this message.
    @details Exposes the window's URL entry field, if needed, and highlights it for text entry.
 */
- (IBAction)openLocation:(id)sender
{
    [self showLoadingBar];
    (void)[self.window makeFirstResponder:self.urlDisplay];
}

/*!
    @brief Action to visit the designated home page.
    @param sender The object that sent this message.
    @details Triggers the user's Default Page to be visited.
 */
- (IBAction)goHome:(id)sender
{
    [self loadPage:self.appDelegate.defaultPage];
}

@end
