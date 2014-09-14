/*!
 @file
 @brief Definition of the controller class for browser windows.
 @details The document encloses a web browser experience.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrBrowserController.h"
#import "PrairieAppDelegate.h"
#import "PrDocumentController.h"
#import "PrUserDefaults.h"


#pragma mark Declared constants

NSString * const  PrBrowserLoadFailedNotification = @"PrBrowserLoadFailedNotification";
NSString * const  PrBrowserLoadPassedNotification = @"PrBrowserLoadPassedNotification";
NSString * const  PrBrowserPrintFailedNotification = @"PrBrowserPrintFailedNotification";
NSString * const  PrBrowserPrintPassedNotification = @"PrBrowserPrintPassedNotification";

NSString * const  PrBrowserURLKey = @"PrBrowserURLKey";
NSString * const  PrBrowserLoadFailedWasProvisionalKey = @"PrBrowserLoadFailedWasProvisionalKey";
NSString * const  PrBrowserErrorKey = @"PrBrowserErrorKey";

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

- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo;

- (void)showError:(NSError *)error;
- (BOOL)isLoadingBarVisible;
- (void)hideLoadingBar;
- (void)showLoadingBar;
- (BOOL)isStatusBarVisible;
- (void)hideStatusBar;
- (void)showStatusBar;

- (void)performPreciseBackOrForward:(id)sender;

//! Centralized access point for user defaults. All instances, whether here, in other controller instances, or in the application delegate, reference the same defaults.
@property (nonatomic, readonly) PrUserDefaults *  defaults;

@end

@implementation PrBrowserController

#pragma mark Conventional overrides

- (id)init
{
    self = [super initWithWindowNibName:[NSStringFromClass([self class]) stringByReplacingOccurrencesOfString:@"Controller" withString:@""]];
    if (self) {
        if (!(_defaults = [PrUserDefaults new])) {
            return nil;
        }
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

    // Personalize user-agent.
    self.webView.applicationNameForUserAgent = [[NSProcessInfo processInfo] processName];
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
    id const  browser = [[NSApp delegate] createBrowser];

    [[browser webView].mainFrame loadRequest:request];
    return [browser webView];
}

- (void)webViewShow:(WebView *)sender
{
    [self showWindow:nil];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text
{
    if (self.defaults.controlStatusBarFromWS) {
        self.statusLine.stringValue = text;
    }  // Calling the version for "super" for an "else" case caused an internal exception, as in no implementation.
}

- (NSString *)webViewStatusText:(WebView *)sender  // UNTESTED
{
    return self.defaults.controlStatusBarFromWS ? self.statusLine.stringValue : [super webViewStatusText:sender];
}

- (BOOL)webViewAreToolbarsVisible:(WebView *)sender
{
    // TODO: add preference control to block these two methods (ControlToolbarsFromWS)
    return [sender.window.toolbar isVisible] || [self isLoadingBarVisible];
}

- (void)webView:(WebView *)sender setToolbarsVisible:(BOOL)visible  // UNTESTED
{
    [sender.window.toolbar setVisible:visible];
    visible ? [self showLoadingBar] : [self hideLoadingBar];
}

- (BOOL)webViewIsStatusBarVisible:(WebView *)sender
{
    return self.defaults.controlStatusBarFromWS ? [self isStatusBarVisible] : NO;  // No "super"
}

- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible  // UNTESTED
{
    self.defaults.controlStatusBarFromWS ? visible ? [self showStatusBar] : [self hideStatusBar] : [super webView:sender setStatusBarVisible:visible];
}

#pragma mark WebFrameLoadDelegate overrides

// The document object is set as the web-view's frame-load-delegate within the XIB.

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {  // Ignore notices from sub-frames.
        [[NSNotificationCenter defaultCenter] postNotificationName:PrBrowserLoadFailedNotification object:self userInfo:@{PrBrowserURLKey: frame.provisionalDataSource.request.URL, PrBrowserLoadFailedWasProvisionalKey: @(YES), PrBrowserErrorKey: error}];
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
            if ([sender.window isVisible]) {  // Don't put secretly-opened files on the list.
                [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:requestURL];
            }
        }
        if (!frame.dataSource.pageTitle) {
            sender.window.title = requestURL.lastPathComponent;
        }

        // Announce that the URL was loaded. (Doing this before setting self.urlDisplay.stringValue crashed it.)
        [[NSNotificationCenter defaultCenter] postNotificationName:PrBrowserLoadPassedNotification object:self userInfo:@{PrBrowserURLKey: requestURL}];

        // Enabled/disabled status of the Back and Forward toolbar buttons.
        NSSegmentedControl * const  backForwardControl = (NSSegmentedControl *)self.toolbarBackForward.view;

        [backForwardControl setEnabled:[sender canGoBack] forSegment:PrGoBackSegment];
        [backForwardControl setEnabled:[sender canGoForward] forSegment:PrGoForwardSegment];

        // Revisit menus for the Back and Forward toolbar buttons.
        WebBackForwardList * const  backForwardList = sender.backForwardList;
        NSMenu *                    backMenu = [[NSMenu alloc] initWithTitle:@""];
        NSMenu *                 forwardMenu = [[NSMenu alloc] initWithTitle:@""];
        __block NSInteger         counterTag = 0;
        NSInteger const        maxMenuLength = self.defaults.backForwardMenuLength;

        for (WebHistoryItem *obj in [backForwardList backListWithLimit:(int)maxMenuLength].reverseObjectEnumerator) {
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
        }  // The history lists go from earliest to latest. The menus need to go from temporally closest to furthest. Those directions are the same for the forward list, but opposing for the back list, so the back list has to be iterated backwards.
        [backForwardControl setMenu:backMenu forSegment:PrGoBackSegment];
        counterTag = 0;
        for (WebHistoryItem *obj in [backForwardList forwardListWithLimit:(int)maxMenuLength]) {
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
        }
        [backForwardControl setMenu:forwardMenu forSegment:PrGoForwardSegment];
    }
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PrBrowserLoadFailedNotification object:self userInfo:@{PrBrowserURLKey: frame.provisionalDataSource.request.URL, PrBrowserLoadFailedWasProvisionalKey: @(NO), PrBrowserErrorKey: error}];
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

#pragma mark Printing delegate

/*!
    @brief Print job completion handler.
    @param printOperation The finished print operation.
    @param success Whether or not the print operation finished successfully.
    @param contextInfo Any extra developer-defined data, like the source URL.
 */
- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo {
    NSURL * const  loadedURL = (__bridge_transfer NSURL *)contextInfo;

    [[NSNotificationCenter defaultCenter] postNotificationName:(success ? PrBrowserPrintPassedNotification : PrBrowserPrintFailedNotification) object:self userInfo:@{PrBrowserURLKey: loadedURL}];
}

#pragma mark Public methods (besides actions)

/*!
    @brief Orders web-view member to load a new URL.
    @param pageURL The URL for the resource to be loaded.
    @details Encapsulates URL loads, packaging the URL into the NSURLRequest object that loadRequest needs. Having this code encapsulated means it can be manipulated by selector games (like adding a delay).

    Will send either a PrBrowserLoadFailedNotification or PrBrowserLoadPassedNotification when the page loading ends. The notification object is this window controller instance. The user dictionary has entries with the desired URL and, if the load failed, a Boolean indicating if the load ended during the provisional or committed phase.
 */
- (void)loadPage:(NSURL *)pageURL
{
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:pageURL]];
}

/*!
    @brief Print the current page.
    @param info Information on the print job.
    @param configure YES to show the Print panel, NO otherwise.
    @param progress YES to show the progress panel, NO otherwise.

    Will send either a PrBrowserPrintFailedNotification or PrBrowserPrintPassedNotification when the print job ends. The notification object is this window controller instance. The user dictionary has an entry with the desired URL.
 */
- (void)printWithInfo:(NSPrintInfo *)info showPrint:(BOOL)configure showProgress:(BOOL)progress {
    NSPrintOperation * const  op = [self.webView.mainFrame.frameView printOperationWithPrintInfo:info];
    NSURL * const      loadedURL = self.webView.mainFrame.dataSource.initialRequest.URL;

    op.showsPrintPanel = configure;
    op.showsProgressPanel = progress;
    [op runOperationModalForWindow:self.window delegate:self didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:(__bridge_retained void *)loadedURL];
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
    PrDocumentController * const  controller = [NSDocumentController sharedDocumentController];

    if ([sender isKindOfClass:[NSMenuItem class]] && [sender tag]) {
        // Have the "Open in New Window…" command instead of the regular "Open…" one. Just do what would happen if this class didn't intercept openDocument:.
        return [controller openDocument:sender];
    }

    NSOpenPanel * const  panel = [NSOpenPanel openPanel];

    panel.delegate = controller.openPanelDelegate;
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
    @brief Action to print the currently displayed resource.
    @param sender The object that sent this message.
 */
- (IBAction)printDocument:(id)sender {
    [self printWithInfo:[NSPrintInfo sharedPrintInfo] showPrint:YES showProgress:YES];
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
    [self loadPage:self.defaults.defaultPage];
}

// See header for details.
- (IBAction)revisitHistory:(id)sender {
    // Sanity check.
    if (![sender isKindOfClass:[NSMenuItem class]]) return;
    if (![[sender representedObject] isKindOfClass:[WebHistoryItem class]]) return;

    // Revisit the page with the current WebView.
    NSMenuItem * const         menuItem = sender;
    WebHistoryItem * const  historyItem = menuItem.representedObject;

    [self loadPage:[NSURL URLWithString:historyItem.URLString]];
}

@end
