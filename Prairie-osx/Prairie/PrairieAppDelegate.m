/*!
    @file
    @brief Definition of the app's delegate class, connected to the main XIB.
    @details The application delegate handles app-global setup, data, and actions.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrairieAppDelegate.h"
#import "PrBrowserController.h"
#import "PrBulkFileOperation.h"

@import CoreServices;


#pragma mark Declared constants

NSString * const  PrDefaultPageKey = @"DefaultPage";
NSString * const  PrDefaultBackForwardMenuLengthKey = @"BackForwardMenuLength";
NSString * const  PrDefaultControlStatusBarFromWSKey = @"ControlStatusBarFromWebScripting";
NSString * const  PrDefaultOpenUntitledToDefaultPageKey = @"OpenUntitledToDefaultPage";

NSString * const  PrDefaultPage = @"http://www.apple.com";
NSInteger const   PrDefaultBackForwardMenuLength = 10;
BOOL const        PrDefaultControlStatusBarFromWS = NO;
BOOL const        PrDefaultOpenUntitledToDefaultPage = YES;

#pragma mark Private interface

@interface PrairieAppDelegate () {
    NSMutableSet *  _windowControllers;
}

@property (nonatomic, readonly) NSMutableSet *  mutableWindowControllers;

@end

@implementation PrairieAppDelegate

#pragma mark Initialization

- (instancetype)init {
    if (self = [super init]) {
        _windowControllers = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Property getters & setters

- (NSURL *)defaultPage
{
    return [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:PrDefaultPageKey]];
}

- (NSInteger)backForwardMenuLength
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:PrDefaultBackForwardMenuLengthKey];
}

- (BOOL)controlStatusBarFromWS
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultControlStatusBarFromWSKey];
}

- (BOOL)openUntitledToDefaultPage {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultOpenUntitledToDefaultPageKey];
}

@synthesize windowControllers = _windowControllers;

- (void)addWindowControllersObject:(PrBrowserController *)controller {
    [_windowControllers addObject:controller];
}

- (void)removeWindowControllersObject:(PrBrowserController *)controller {
    [_windowControllers removeObject:controller];
}

- (NSMutableSet *)mutableWindowControllers {
    return [self mutableSetValueForKey:@"windowControllers"];  // Change the string if the corresponding property is renamed.
}

#pragma mark Public methods (besides actions)

/*!
    @brief Create a browser window (and matching controller).
    @details If successful, the new controller is added to self.windowControllers.
    @return The new browser window's controller (PrBrowserController), NULL if something failed.
 */
- (id)createBrowser {
    NSWindow * const  browserWindow = [[[PrBrowserController alloc] init] window];  // Loads window's XIB.

    if (browserWindow) {
        id const  browser = browserWindow.windowController;

        [self.mutableWindowControllers addObject:browser];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyOnWindowClose:) name:NSWindowWillCloseNotification object:browserWindow];
        return browser;
    }
    return nil;
}

#pragma mark NSApplicationDelegate overrides

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
    if (![PrBulkFileOperation openFiles:filenames application:sender]) {
        [sender replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
    }
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender {
    PrBrowserController * const  browser = [self createBrowser];

    [browser showWindow:sender];
    if (self.openUntitledToDefaultPage) {
        [browser goHome:sender];
    } else {
        [browser openLocation:sender];
    }
    return !!browser;  // Can't use [self (goHome/openLocation):sender] because those wouldn't give me the created PrBrowserController instance, which is needed for the return value. The result ignores the possibility that the home page could fail to load, since the window stays up.
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // If there's a new window, file open, or file print on app launch, then those will be done after this method but before applicationDidFinishLaunching:, so anything setup required for any created windows needs to be done here.

    // Last-resort preference settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PrDefaultPageKey: PrDefaultPage, PrDefaultBackForwardMenuLengthKey: @(PrDefaultBackForwardMenuLength), PrDefaultControlStatusBarFromWSKey: @(PrDefaultControlStatusBarFromWS), PrDefaultOpenUntitledToDefaultPageKey: @(PrDefaultOpenUntitledToDefaultPage)}];
}

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

#pragma mark Notifications

/*!
    @brief Response to NSWindowWillCloseNotification.
    @param notification The sent notification.
    @details Removes the given window's controller from the controller list.
 */
- (void)notifyOnWindowClose:(NSNotification *)notification {
    [self.mutableWindowControllers removeObject:[notification.object windowController]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:notification.object];
}

#pragma mark Action methods

/*!
    @brief Action to create a new browser window.
    @param sender The object that sent this message.
 */
- (IBAction)newDocument:(id)sender {
    [self applicationOpenUntitledFile:NSApp];
}

/*!
    @brief Action to open a (file) URL in a new browser window.
    @param sender The object that sent this message.
 */
- (IBAction)openDocument:(id)sender {
    NSOpenPanel * const  panel = [NSOpenPanel openPanel];

    panel.allowsMultipleSelection = YES;
    panel.delegate = self;
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSAppleEventDescriptor * const   fileList = [NSAppleEventDescriptor listDescriptor];
            NSAppleEventDescriptor * const  openEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenDocuments targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

            for (NSURL *file in panel.URLs) {
                [fileList insertDescriptor:[NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:[[file absoluteString] dataUsingEncoding:NSUTF8StringEncoding]] atIndex:0];
            }
            [openEvent setParamDescriptor:fileList forKeyword:keyDirectObject];
            [[NSAppleEventManager sharedAppleEventManager] dispatchRawAppleEvent:[openEvent aeDesc] withRawReply:(AppleEvent *)[[NSAppleEventDescriptor nullDescriptor] aeDesc] handlerRefCon:(SRefCon)0];
        }
    }];
}

/*!
    @brief Action to start entering an URL for browsing.
    @param sender The object that sent this message.
    @details Called only if there's no browser windows. So create one first, then proceed as normal.
 */
- (IBAction)openLocation:(id)sender
{
    PrBrowserController * const  browser = [self createBrowser];

    [browser showWindow:sender];
    [browser openLocation:sender];
}

/*!
    @brief Action to visit the designated home page.
    @param sender The object that sent this message.
    @details Called only if there's no browser windows. So create one first, then proceed as normal.
 */
- (IBAction)goHome:(id)sender
{
    PrBrowserController * const  browser = [self createBrowser];
    
    [browser showWindow:sender];
    [browser goHome:sender];
}

@end
