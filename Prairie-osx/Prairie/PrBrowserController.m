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
#import "PrSourceViewController.h"


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

// Keys for the 'postLoadActions' dictionary.
//! This dictionary key points to a NSString object with the new page's window title.
static NSString * const  PrLoadActionSetTitleKey = @"title";
//! This dictionary key points to a NSString object that is the search string.
static NSString * const  PrLoadActionSearchKey = @"search";
//! This dictionary key points to a NSPrintInfo object that is the print record.
static NSString * const  PrLoadActionPrintInfoKey = @"print info";
//! This dictionary key points to a BOOL in an NSNumber object indicating whether to show the Print panel.
static NSString * const  PrLoadActionPrintPanelKey = @"print panel";
//! This dictionary key points to a BOOL in an NSNumber object indicating whether to show the Print-Progress panel.
static NSString * const  PrLoadActionPrintProgressKey = @"print progress";

// Keys for restorable properties.
//! Key-path string for the 'postLoadActions' property.
static NSString * const  PrKeyPathPostLoadActions = @"postLoadActions";
//! Dictionary key string for the URL string of a WebHistoryItem.
static NSString * const  PrURLStringKey = @"URL String";
//! Dictionary key string for the title of a WebHistoryItem.
static NSString * const  PrTitleKey = @"Title";
//! Dictionary key string for the last-visited time-interval of a WebHistoryItem.
static NSString * const  PrLastVisitedTimeIntervalKey = @"Last Visited Time Interval";
//! Dictionary key string for an alternate title of a WebHistoryItem.
static NSString * const  PrAlternateTitleKey = @"Alternate Title";
//! Archive key string for the WebView's back-list.
static NSString * const  PrBackListKey = @"Back List";
//! Archive key string for the WebView's current item.
static NSString * const  PrCurrentItemKey = @"Current Item";
//! Archive key string for the WebView's forward-list.
static NSString * const  PrForwardListKey = @"Forward List";

#pragma mark File-local functions

/*!
    @brief Makes a dictionary representing the attributes of a web-history item.
    @param item The web-history entry to be copied.
    @return A dictionary with the re-creatable attributes of a web-history item.
 */
static inline
NSDictionary *  CreateDictionaryForWebHistoryItem(WebHistoryItem *item) {
    NSMutableDictionary * const  dict = [NSMutableDictionary dictionaryWithDictionary:@{PrLastVisitedTimeIntervalKey: @(item.lastVisitedTimeInterval)}];

    if (item.originalURLString) {
        [dict setObject:item.originalURLString forKeyedSubscript:PrURLStringKey];
    }
    if (item.title) {
        [dict setObject:item.title forKeyedSubscript:PrTitleKey];
    }
    if (item.alternateTitle) {
        [dict setObject:item.alternateTitle forKeyedSubscript:PrAlternateTitleKey];
    }
    return dict;
}

/*!
    @brief Makes a web-history item from attributes stored in a dictionary.
    @param dict The dictionary to be read.
    @return A web-history item with attributes copied from the dictionary.
 */
static inline
WebHistoryItem *  CreateWebHistoryItemFromDictionary(NSDictionary *dict) {
    WebHistoryItem * const  item = [[WebHistoryItem alloc] initWithURLString:dict[PrURLStringKey] title:dict[PrTitleKey] lastVisitedTimeInterval:[dict[PrLastVisitedTimeIntervalKey] doubleValue]];
    NSString * const        alternateTitle = dict[PrAlternateTitleKey];

    if (alternateTitle) {
        item.alternateTitle = alternateTitle;
    }
    return item;
}

#pragma mark - Private interface

@interface PrBrowserController () <NSWindowRestoration>

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
/*!
    @brief Calls printWithInfo:showPrint:showProgress: with the data stored in 'postLoadActions'. Assumes the data required is actually there, so check first.
 */
- (void)printWithPostLoadInfo;
/*!
    @brief Sets the Back and Forward toolbar buttons to match the WebView's history state.
 */
- (void)prepareBackForwardButtons;
/*!
    @brief The core name of this class, used for the XIB name and its window identifier.
    @return The name of this class, minus the "Controller" part.
 */
+ (NSString *)coreName;
/*!
    @brief Performs the User-Interface State-Restoration finishing calls, if needed.
 */
- (void)finishStateRestoration;

- (void)performPreciseBackOrForward:(id)sender;
/*!
    @brief Action for menu items within the window title-bar command-click menu for non-file URLs.
    @param sender The object that sent this message.
    @details Checks which menu item was clicked, and instructs the associated WebView to go to that item's URL.
 */
- (void)goToParent:(id)sender;

//! Centralized access point for user defaults.
@property (nonatomic, readonly) PrUserDefaults *  defaults;
//! Directions on what to do after the next page load. Starts as nil. Should be KVO-compliant.
@property (nonatomic) NSDictionary *              postLoadActions;
//! Indicate that user-interface restore is happening. Starts as NO.
@property (nonatomic, assign, getter=isRestoring) BOOL  restoring;

@end

@implementation PrBrowserController

#pragma mark Factory methods

// See header for details.
+ (instancetype)createBrowser {
    PrBrowserController * const  controller = [self new];
    NSWindow * const                 window = controller.window;  // Force creation of window.
    
    if (window) {
        [[NSApp delegate] registerWindow:window];
    }
    return controller;
}

#pragma mark Conventional overrides

- (instancetype)init {
    if (self = [super initWithWindowNibName:[self.class coreName]]) {
        if (!(_defaults = [PrUserDefaults sharedInstance])) {
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

    // Point to restoration class.
    self.window.restorationClass = self.class;

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

#pragma mark NSWindowRestoration override

+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
    if ([identifier isEqualToString:[self.class coreName]]) {
        NSWindow * const  window = [[self createBrowser] window];

        if (window) {
            [window.windowController setRestoring:YES];
            [NSApp extendStateRestoration];
        }
        completionHandler(window, nil);
    } else {
        completionHandler(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil]);
    }
}

#pragma mark NSRestorableState overrides

+ (NSArray *)restorableStateKeyPaths {
    return [[super restorableStateKeyPaths] arrayByAddingObject:PrKeyPathPostLoadActions];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    WebBackForwardList * const  backForwardList = self.webView.backForwardList;

    [super encodeRestorableStateWithCoder:coder];
    if (backForwardList.currentItem) {
        int const  backListCount = backForwardList.backListCount, forwardListCount = backForwardList.forwardListCount;

        if (backListCount) {
            NSMutableArray * const  backArray = [[NSMutableArray alloc] initWithCapacity:backListCount];

            for (WebHistoryItem *item in [backForwardList backListWithLimit:backListCount]) {
                [backArray addObject:CreateDictionaryForWebHistoryItem(item)];
            }
            [coder encodeObject:backArray forKey:PrBackListKey];
        }
        [coder encodeObject:CreateDictionaryForWebHistoryItem(backForwardList.currentItem) forKey:PrCurrentItemKey];
        if (forwardListCount) {
            NSMutableArray * const  forwardArray = [[NSMutableArray alloc] initWithCapacity:forwardListCount];

            for (WebHistoryItem *item in [backForwardList forwardListWithLimit:forwardListCount]) {
                [forwardArray addObject:CreateDictionaryForWebHistoryItem(item)];
            }
            [coder encodeObject:forwardArray forKey:PrForwardListKey];
        }
    }
}

- (void)restoreStateWithCoder:(NSCoder *)coder {
    NSDictionary *  currentItemDictionary;

    [super restoreStateWithCoder:coder];
    if ((currentItemDictionary = [coder decodeObjectOfClass:[NSDictionary class] forKey:PrCurrentItemKey])) {
        WebHistoryItem * const  currentItem = CreateWebHistoryItemFromDictionary(currentItemDictionary);

        for (NSDictionary *dict in [coder decodeObjectOfClass:[NSArray class] forKey:PrBackListKey]) {
            [self.webView.backForwardList addItem:CreateWebHistoryItemFromDictionary(dict)];
        }
        [self.webView.backForwardList addItem:currentItem];
        for (NSDictionary *dict in [coder decodeObjectOfClass:[NSArray class] forKey:PrForwardListKey]) {
            [self.webView.backForwardList addItem:CreateWebHistoryItemFromDictionary(dict)];
        }

        [self.webView performSelectorOnMainThread:@selector(goToBackForwardItem:) withObject:currentItem waitUntilDone:NO];
    } else {
        [self finishStateRestoration];
    }
}

#pragma mark NSWindowDelegate overrides

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame {
    NSParameterAssert(self.window == window);

    // Based on the web content, get the maximum desired width and height.
    NSView<WebDocumentView> * const  view = self.webView.mainFrame.frameView.documentView;
    NSSize const       desiredContentSize = NSMakeSize(NSWidth(view.frame), NSHeight(view.frame) + ((CGFloat)!!self.isLoadingBarVisible * PrLoadingBarHeight) + ((CGFloat)!!self.isStatusBarVisible * PrStatusBarHeight));

    // Adjust that desired size to what's actually available.
    NSRect  frame = [window contentRectForFrameRect:newFrame];

    frame.size.width = MIN(desiredContentSize.width, frame.size.width);
    frame.size.height = MIN(desiredContentSize.height, frame.size.height);

    // Adjust to the window's size bounds.
    frame = [window frameRectForContentRect:frame];
    frame.size.width = MAX(window.minSize.width, frame.size.width);
    frame.size.height = MAX(window.minSize.height, frame.size.height);
    NSAssert(frame.size.width <= newFrame.size.width, @"Standard web-browser window size too wide.");
    NSAssert(frame.size.height <= newFrame.size.height, @"Standard web-browser window size too tall.");

    // Try minimizing the amount the window moves from its current spot on the chosen screen.
    NSRect const  oldOverlapFrame = NSIntersectionRect(window.frame, newFrame);

    frame = NSOffsetRect(frame, NSMidX(oldOverlapFrame) - NSMidX(frame), NSMidY(oldOverlapFrame) - NSMidY(frame));
    if (NSMaxX(frame) > NSMaxX(newFrame)) {
        frame = NSOffsetRect(frame, NSMaxX(newFrame) - NSMaxX(frame), 0.0);
    } else if (NSMinX(frame) < NSMinX(newFrame)) {
        frame = NSOffsetRect(frame, NSMinX(newFrame) - NSMinX(frame), 0.0);
    }
    if (NSMaxY(frame) > NSMaxY(newFrame)) {
        frame = NSOffsetRect(frame, 0.0, NSMaxY(newFrame) - NSMaxY(frame));
    } else if (NSMinY(frame) < NSMinY(newFrame)) {
        frame = NSOffsetRect(frame, 0.0, NSMinY(newFrame) - NSMinY(frame));
    }

    return frame;
}

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu {
    // Use default behavior for file URLs and URLs not using the common Internet scheme syntax.
    NSURL *  url = [NSURL URLWithString:self.webView.mainFrameURL];

    NSParameterAssert(self.window == window);
    if (!url || url.isFileURL || !url.host) {
        return !!menu.numberOfItems;
    }

    // Add the current URL and each parent directory down to the server.
    [menu removeAllItems];
    [menu addItemWithTitle:url.absoluteString action:nil keyEquivalent:@""].state = NSOffState;
    while (url.path && ![url.path isEqualToString:@"/"]) {
        url = [url URLByDeletingLastPathComponent];
        (void)[menu addItemWithTitle:url.absoluteString action:@selector(goToParent:) keyEquivalent:@""];
    }

    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    [self finishStateRestoration];  // Assume a close during User-Interface Resume is user-initiated.
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
    } else if (action == @selector(viewSource:)) {
        id<WebDocumentRepresentation> const  representation = [self.webView.mainFrame.dataSource representation];

        return representation && [representation canProvideDocumentSource];
    }
    return YES;
}

#pragma mark WebUIDelegate overrides

// The document object is set as the web-view's UI-delegate within the XIB.

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
    PrBrowserController * const  browser = [PrBrowserController createBrowser];

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
        [self finishStateRestoration];
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
        [self finishStateRestoration];
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
            sender.window.title = [requestURL.lastPathComponent stringByRemovingPercentEncoding];
        }

        // Announce that the URL was loaded. (Doing this before setting self.urlDisplay.stringValue crashed it.)
        [[NSNotificationCenter defaultCenter] postNotificationName:PrBrowserLoadPassedNotification object:self userInfo:@{PrBrowserURLKey: requestURL}];

        // Handle Back and Forward toolbar buttons.
        [self prepareBackForwardButtons];

        // Do any post-loading actions.
        NSString * const    postLoadTitle = self.postLoadActions[PrLoadActionSetTitleKey];
        NSString * const   postLoadSearch = self.postLoadActions[PrLoadActionSearchKey];
        NSPrintInfo * const  postLoadInfo = self.postLoadActions[PrLoadActionPrintInfoKey];

        if (postLoadTitle) {
            self.window.title = sender.backForwardList.currentItem.alternateTitle = postLoadTitle;
        }
        if (postLoadSearch) {
            (void)[sender searchFor:postLoadSearch direction:YES caseSensitive:NO wrap:YES];
        }
        if (postLoadInfo) {
            [self performSelector:@selector(printWithPostLoadInfo) withObject:nil afterDelay:0.0];
        }

        // Make sure to save any updates to the Back/Forward list
        [self invalidateRestorableState];
    }
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == sender.mainFrame) {
        [self finishStateRestoration];
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

// See header for details.
- (void)loadPage:(NSURL *)pageURL title:(NSString *)pageTitle searching:(NSString *)search printing:(NSPrintInfo *)info showPrint:(BOOL)configure showProgress:(BOOL)progress {
    // Prepare extra arguments. Clears out data from any previous page load, even if nil.
    NSMutableDictionary * const  loadingActions = [[NSMutableDictionary alloc] initWithCapacity:5];

    if (pageTitle) {
        [loadingActions setObject:pageTitle forKeyedSubscript:PrLoadActionSetTitleKey];
    }
    if (search) {
        [loadingActions setObject:search forKeyedSubscript:PrLoadActionSearchKey];
    }
    if (info) {
        [loadingActions setObject:info forKeyedSubscript:PrLoadActionPrintInfoKey];
        [loadingActions setObject:@(configure) forKeyedSubscript:PrLoadActionPrintPanelKey];
        [loadingActions setObject:@(progress) forKeyedSubscript:PrLoadActionPrintProgressKey];
    }
    self.postLoadActions = loadingActions;

    // Request the page.
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:pageURL]];
}

/*!
    @brief Orders web-view member to load a new URL.
    @param pageURL The URL for the resource to be loaded.
    @details Acts like loadPage:title:searching:printing:showPrint:showProgress: with all arguments after the first one either nil or ignored. Sends the same notifications (without the ones relating to printing). Having the most basic case encapsulated means it can be manipulated by selector games (like adding a delay).
 */
- (void)loadPage:(NSURL *)pageURL
{
    [self loadPage:pageURL title:nil searching:nil printing:nil showPrint:NO showProgress:NO];
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

// See private interface for details.
- (void)printWithPostLoadInfo {
    [self printWithInfo:self.postLoadActions[PrLoadActionPrintInfoKey] showPrint:[self.postLoadActions[PrLoadActionPrintPanelKey] boolValue] showProgress:[self.postLoadActions[PrLoadActionPrintProgressKey] boolValue]];
}

// See private interface for details.
- (void)prepareBackForwardButtons {
    // Preliminaries
    NSSegmentedControl * const  backForwardControl = (NSSegmentedControl *)self.toolbarBackForward.view;
    WebView * const             webControl = self.webView;
    WebBackForwardList * const  backForwardList = webControl.backForwardList;
    NSInteger const             menuLength = self.defaults.backForwardMenuLength;

    // Enabled/disabled status
    [backForwardControl setEnabled:webControl.canGoBack forSegment:PrGoBackSegment];
    [backForwardControl setEnabled:webControl.canGoForward forSegment:PrGoForwardSegment];

    // Back button menu
    NSMenu * const  backMenu = [[NSMenu alloc] initWithTitle:@""];
    NSInteger     counterTag = 0;

    for (WebHistoryItem *item in [backForwardList backListWithLimit:(int)menuLength].reverseObjectEnumerator) {  // Reverse-iteration since history lists go from earliest to latest but the menu items need to go from temporally closest to furthest.
        NSString *  itemTitle = item.title;

        if (nil == itemTitle) {
            if (!(itemTitle = item.alternateTitle)) {
                itemTitle = [[[NSURL URLWithString:item.URLString] lastPathComponent] stringByRemovingPercentEncoding];
            }
        }
        NSMenuItem * const  backMenuItem = [[NSMenuItem alloc] initWithTitle:itemTitle action:@selector(performPreciseBackOrForward:) keyEquivalent:@""];

        backMenuItem.tag = --counterTag;
        backMenuItem.toolTip = item.originalURLString;
        backMenuItem.target = self;
        [backMenu insertItem:backMenuItem atIndex:-counterTag - 1];
    }
    [backForwardControl setMenu:backMenu forSegment:PrGoBackSegment];

    // Forward button menu
    NSMenu * const  forwardMenu = [[NSMenu alloc] initWithTitle:@""];

    counterTag = 0;
    for (WebHistoryItem *item in [backForwardList forwardListWithLimit:(int)menuLength]) {
        NSString *  itemTitle = item.title;

        if (nil == itemTitle) {
            if (!(itemTitle = item.alternateTitle)) {
                itemTitle = [[[NSURL URLWithString:item.URLString] lastPathComponent] stringByRemovingPercentEncoding];
            }
        }
        NSMenuItem * const  forwardMenuItem = [[NSMenuItem alloc] initWithTitle:itemTitle action:@selector(performPreciseBackOrForward:) keyEquivalent:@""];
        forwardMenuItem.tag = ++counterTag;
        forwardMenuItem.toolTip = item.originalURLString;
        forwardMenuItem.target = self;
        [forwardMenu insertItem:forwardMenuItem atIndex:+counterTag - 1];
    }
    [backForwardControl setMenu:forwardMenu forSegment:PrGoForwardSegment];
}

// See private interface for details.
+ (NSString *)coreName {
    return [NSStringFromClass(self) stringByReplacingOccurrencesOfString:@"Controller" withString:@""];
}

// See private interface for details.
- (void)finishStateRestoration {
    if (self.isRestoring) {
        self.restoring = NO;
        [NSApp completeStateRestoration];
    }
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

// See private interface for details
- (void)goToParent:(id)sender {
    NSParameterAssert([sender isKindOfClass:[NSMenuItem class]]);
    [self loadPage:[NSURL URLWithString:[sender title]]];
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
            __block NSError *   error = nil;
            NSFileCoordinator *  sync = [[NSFileCoordinator alloc] initWithFilePresenter:nil];

            [sync coordinateWritingItemAtURL:panel.URL options:NSFileCoordinatorWritingForReplacing error:&error byAccessor:^(NSURL *newURL) {
                (void)[([fileTypes firstObjectCommonWithArray:(__bridge_transfer NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)panel.URL.pathExtension, nil)] ? source.data : source.webArchive.data) writeToURL:newURL options:NSDataWritingAtomic error:&error];
            }];
            if (error) {
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

// See header for details.
- (IBAction)viewSource:(id)sender {
    return [[PrSourceViewController createViewerOfSource:self.webView.mainFrame.dataSource] showWindow:sender];
}

@end
