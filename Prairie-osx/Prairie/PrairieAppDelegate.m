/*!
    @file
    @brief Definition of the app's delegate class, connected to the main XIB.
    @details The application delegate handles app-global setup, data, and actions.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrairieAppDelegate.h"
#import "PrBrowserController.h"
#import "PrFileOpener.h"
#import "PrGetURLHandler.h"

@import ApplicationServices;
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

#pragma mark File-local constants

static NSString * const  keyPathFinished = @"finished";  // from PrFileOpener

#pragma mark Private interface

@interface PrairieAppDelegate () {
    NSMutableSet *  _windowControllers;
}

- (void)notifyOnWindowClose:(NSNotification *)notification;
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply;

@property (nonatomic, readonly) NSMutableSet *  mutableWindowControllers;
@property (nonatomic, readonly) NSMutableSet *  openFilers;

@end

@implementation PrairieAppDelegate

#pragma mark Initialization

- (instancetype)init {
    if (self = [super init]) {
        _windowControllers = [[NSMutableSet alloc] init];
        _openFilers = [[NSMutableSet alloc] init];
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
    PrFileOpener * const  opener = [[PrFileOpener alloc] initWithFiles:filenames application:sender];

    if (opener) {
        [self.openFilers addObject:opener];
        [opener addObserver:self forKeyPath:keyPathFinished options:NSKeyValueObservingOptionNew context:NULL];
        opener.search = [[[[NSAppleEventManager sharedAppleEventManager] currentAppleEvent] paramDescriptorForKeyword:keyAESearchText] stringValue];
        [opener performSelector:@selector(start) withObject:nil afterDelay:0.0];
    } else {
        [sender replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
    }
}

- (NSApplicationPrintReply)application:(NSApplication *)application printFiles:(NSArray *)fileNames withSettings:(NSDictionary *)printSettings showPrintPanels:(BOOL)showPrintPanels {
    PrFileOpener * const  printer = [[PrFileOpener alloc] initWithFiles:fileNames application:application];
    NSPrintInfo * const   printSettings2 = [[NSPrintInfo alloc] initWithDictionary:printSettings];

    if (printer && printSettings2) {
        [self.openFilers addObject:printer];
        [printer addObserver:self forKeyPath:keyPathFinished options:NSKeyValueObservingOptionNew context:NULL];
        printer.settings = printSettings2;
        printer.showPrintPanel = showPrintPanels;
        [printer performSelector:@selector(start) withObject:nil afterDelay:0.0];
        return NSPrintingReplyLater;
    } else {
        return NSPrintingFailure;
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

    // Open remote URLs
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:replyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
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

#pragma mark NSKeyValueObserving override

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id const  newFinished = change[NSKeyValueChangeNewKey];

    if ([self.openFilers containsObject:object] && [keyPath isEqualToString:keyPathFinished] && (newFinished && [newFinished isKindOfClass:[NSNumber class]] && [newFinished boolValue])) {
        [object removeObserver:self forKeyPath:keyPathFinished context:context];
        [self.openFilers removeObject:object];
    }
}

#pragma mark Apple event handlers

/*!
    @brief Handler for the Get-URL Apple event.
    @param event The event with the command.
    @param reply The event to post any response (unless it's of typeNull).
 */
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply {
    PrGetURLHandler * const  handler = [[PrGetURLHandler alloc] init];

    if (handler) {
        [self.openFilers addObject:handler];
        [handler addObserver:self forKeyPath:keyPathFinished options:NSKeyValueObservingOptionNew context:NULL];
        [handler performSelector:@selector(start) withObject:nil afterDelay:0.0];
    } else if (reply.descriptorType != typeNull) {
        [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:unimpErr] forKeyword:keyErrorNumber];
    }
}

#pragma mark Action methods

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
