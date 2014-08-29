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
@import WebKit;


#pragma mark Declared constants

NSString * const  PrDefaultPageKey = @"DefaultPage";
NSString * const  PrDefaultBackForwardMenuLengthKey = @"BackForwardMenuLength";
NSString * const  PrDefaultControlStatusBarFromWSKey = @"ControlStatusBarFromWebScripting";
NSString * const  PrDefaultOpenUntitledToDefaultPageKey = @"OpenUntitledToDefaultPage";
NSString * const  PrDefaultUseValidateHistoryMenuItemKey = @"UseValidateHistoryMenuItem";
NSString * const  PrDefaultLoadSaveHistoryKey = @"LoadSaveHistory";

NSString * const  PrDefaultPage = @"http://www.apple.com";
NSInteger const   PrDefaultBackForwardMenuLength = 10;
BOOL const        PrDefaultControlStatusBarFromWS = NO;
BOOL const        PrDefaultOpenUntitledToDefaultPage = YES;
BOOL const        PrDefaultUseValidateHistoryMenuItem = NO;
BOOL const        PrDefaultLoadSaveHistory = YES;

#pragma mark File-local constants

static NSString * const  keyPathFinished = @"finished";  // from PrFileOpener

static NSString * const    PrHistoryFilenameV1 = @"History";
#define PrHistoryFilename  PrHistoryFilenameV1  // Can't point to another NSString and stay a compile-time constant.

// Keys of the preference dictionary for non-user entries.
//! Preference key for "historyFileBookmark".
static NSString * const  PrDefaultHistoryFileBookmarkKey = @"HistoryFileBookmark";

#pragma mark Private interface

@interface PrairieAppDelegate () {
    NSMutableSet *  _windowControllers;
}

/*!
    @brief Load the user's History file.
    @details If the "loadSaveHistory" property is NO, does nothing. Otherwise, loads the cached WebHistory store from a file location stored as bookmark data in another property. The "readHistory" property is changed to YES if the store is read. Updates bookmark data as needed.
 */
- (void)recallHistory;
/*!
    @brief Save the user's History file.
    @details If the "loadSaveHistory" property is NO, does nothing. Otherwise saves the WebHistory store to a cache file, whose location is either stored as bookmark data in another property or will be stored there once the file is created at a default URL. If the cached file has not been read yet (i.e., the "readHistory" property is NO), attempt reading it in and, if successful, merge the stores before writing.

    The merged-histories scenario can occur if the "loadSaveHistory" property changes from NO to YES within a session.
 */
- (void)preserveHistory;

- (void)notifyOnWindowClose:(NSNotification *)notification;
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply;

@property (nonatomic, readonly) NSMutableSet *  mutableWindowControllers;
@property (nonatomic, readonly) NSMutableSet *  openFilers;
@property (nonatomic, assign)   BOOL            readHistory;  // Whether or not History file has been read.
@property (nonatomic, readonly, copy) NSURL *   defaultHistoryFileURL;  // Default location for the History file.

// Non-user (i.e. private) preferences
//! Bookmark for the History file. Valid when the WebHistory store gets saved at least once.
@property (nonatomic) NSData *  historyFileBookmark;

@end

@implementation PrairieAppDelegate

#pragma mark Initialization

- (instancetype)init {
    if (self = [super init]) {
        WebHistory * const  history = [[WebHistory alloc] init];

        _windowControllers = [[NSMutableSet alloc] init];
        _openFilers = [[NSMutableSet alloc] init];
        if (history && _windowControllers && _openFilers) {
            [WebHistory setOptionalSharedHistory:history];
        } else {
            return nil;
        }
        _readHistory = NO;
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

- (BOOL)useValidateHistoryMenuItem {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultUseValidateHistoryMenuItemKey];
}

- (BOOL)loadSaveHistory {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrDefaultLoadSaveHistoryKey];
}

- (NSURL *)applicationSupportDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:[NSRunningApplication currentApplication].bundleIdentifier isDirectory:YES];
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

- (NSURL *)defaultHistoryFileURL {
    return [self.applicationSupportDirectory URLByAppendingPathComponent:PrHistoryFilename];
}

- (NSData *)historyFileBookmark {
    return [[NSUserDefaults standardUserDefaults] dataForKey:PrDefaultHistoryFileBookmarkKey];
}

- (void)setHistoryFileBookmark:(NSData *)historyFileBookmark {
    [[NSUserDefaults standardUserDefaults] setObject:historyFileBookmark forKey:PrDefaultHistoryFileBookmarkKey];
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
    [[NSUserDefaults standardUserDefaults]
     registerDefaults:@{
                        PrDefaultPageKey: PrDefaultPage,
                        PrDefaultBackForwardMenuLengthKey: @(PrDefaultBackForwardMenuLength),
                        PrDefaultControlStatusBarFromWSKey: @(PrDefaultControlStatusBarFromWS),
                        PrDefaultOpenUntitledToDefaultPageKey: @(PrDefaultOpenUntitledToDefaultPage),
                        PrDefaultUseValidateHistoryMenuItemKey: @(PrDefaultUseValidateHistoryMenuItem),
                        PrDefaultLoadSaveHistoryKey: @(PrDefaultLoadSaveHistory)
                        }];

    // Open remote URLs
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:replyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    // Use app-global web-history.
    (void)[[NSFileManager defaultManager] createDirectoryAtURL:self.applicationSupportDirectory withIntermediateDirectories:YES attributes:nil error:nil];  // WebHistory's -saveToURL:error: won't create intermediate directories.
    [self recallHistory];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // Use app-global web-history.
    [self preserveHistory];
}

#pragma mark NSKeyValueObserving override

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id const  newFinished = change[NSKeyValueChangeNewKey];

    if ([self.openFilers containsObject:object] && [keyPath isEqualToString:keyPathFinished] && (newFinished && [newFinished isKindOfClass:[NSNumber class]] && [newFinished boolValue])) {
        [object removeObserver:self forKeyPath:keyPathFinished context:context];
        [self.openFilers removeObject:object];
    }
}

#pragma mark NSMenuValidation override

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL const  action = [menuItem action];
    
    if (action == @selector(validateHistory:)) {
        menuItem.title = [WebHistory optionalSharedHistory].orderedLastVisitedDays.count ? NSLocalizedString(@"HISTORY_STORE_NONEMPTY", nil) : NSLocalizedString(@"HISTORY_STORE_EMPTY", nil);
        return self.useValidateHistoryMenuItem;
    }
    return YES;
}

#pragma mark Private methods

// See private interface for details.
- (void)recallHistory {
    if (!self.loadSaveHistory) return;  // Respect the preference for having an external copy.

    BOOL          stale = NO;
    NSError *     error = nil;
    NSURL *  historyURL = [NSURL URLByResolvingBookmarkData:self.historyFileBookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];

    if (historyURL) {
        if (stale) {
            NSData * const  newBookmark = [historyURL bookmarkDataWithOptions:kNilOptions includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

            if (newBookmark) {
                self.historyFileBookmark = newBookmark;
            }
        }
        if ([[WebHistory optionalSharedHistory] loadFromURL:historyURL error:&error]) {
            self.readHistory = YES;
        }
    }
}

// See private interface for details.
- (void)preserveHistory {
    if (!self.loadSaveHistory) return;  // Respect the preference for having an external copy.

    // Make a last effort to read and merge the old History before splattering it with the new.
    WebHistory  *currentHistory = [WebHistory optionalSharedHistory], *oldHistory = [[WebHistory alloc] init];

    if (!self.readHistory && oldHistory) {
        [WebHistory setOptionalSharedHistory:oldHistory];
        [self recallHistory];
        if (self.readHistory) {
            for (NSCalendarDate *day in currentHistory.orderedLastVisitedDays.reverseObjectEnumerator) {
                [oldHistory addItems:[currentHistory orderedItemsLastVisitedOnDay:day]];
            }
            // When History menus are implemented, add command to redo (uninstall & rebuild) them here.
            // When History update notifications are implemented, add command to reconnect them here.
        } else {
            [WebHistory setOptionalSharedHistory:currentHistory];
            oldHistory = nil;
        }
    }

    // Write out the data.
    BOOL       stale = NO;
    NSError *  error = nil;
    NSURL *    historyURL = [NSURL URLByResolvingBookmarkData:self.historyFileBookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];

    if (historyURL) {
        if (stale) {
            NSData * const  newBookmark = [historyURL bookmarkDataWithOptions:kNilOptions includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            
            if (newBookmark) {
                self.historyFileBookmark = newBookmark;
            }
        }
        stale = NO;  // repurpose to indicate bookmark data does not need to be (re)calculated.
    } else {
        historyURL = self.defaultHistoryFileURL;
        stale = YES;  // repurpose to indicate bookmark data needs to be (re)calculated.
    }

    if ([[WebHistory optionalSharedHistory] saveToURL:historyURL error:&error]) {
        if (stale) {
            self.historyFileBookmark = [historyURL bookmarkDataWithOptions:kNilOptions includingResourceValuesForKeys:nil relativeToURL:nil error:&error];  // If creating bookmark fails, try again next session.
        }
    }
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

/*!
    @brief Action to display web-history statistics.
    @param sender The object that sent this message.
    @details Mainly a placeholder to track the History title menu item.
 */
- (IBAction)validateHistory:(id)sender {
    // Check how many items are there.
    WebHistory * const  history = [WebHistory optionalSharedHistory];
    NSUInteger         dayCount = 0u, itemCount = 0u;

    for (NSCalendarDate *day in history.orderedLastVisitedDays) {
        ++dayCount;
        itemCount += [history orderedItemsLastVisitedOnDay:day].count;
    }

    // Build the alert.
    NSAlert * const  alert = [[NSAlert alloc] init];

    alert.alertStyle = NSInformationalAlertStyle;
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"HISTORY_COUNT_MSG_ITEMS", nil), (unsigned long)itemCount, (unsigned long)history.historyItemLimit];
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"HISTORY_COUNT_MSG_DAYS", nil), (unsigned long)dayCount, (unsigned long)history.historyAgeInDaysLimit];
    (void)[alert runModal];
}

/*!
    @brief Action to purge the web-history store.
    @param sender The object that sent this message.
 */
- (IBAction)clearHistory:(id)sender {
    NSAlert * const  alert = [[NSAlert alloc] init];

    alert.alertStyle = NSWarningAlertStyle;
    alert.messageText = NSLocalizedString(@"CLEAR_HISTORY_CONFIRM_MSG", nil);
    alert.informativeText = NSLocalizedString(@"CLEAR_HISTORY_INFO_MSG", nil);

    (void)[alert addButtonWithTitle:NSLocalizedString(@"CLEAR_BUTTON", nil)];  // This and the next statement are order-dependent.
    (void)[alert addButtonWithTitle:NSLocalizedString(@"CANCEL", nil)];
    [alert.buttons[0] setKeyEquivalent:@""];  // Do not enable a destructive action with Return!

    switch ([alert runModal]) {
        case NSAlertFirstButtonReturn:
            [[WebHistory optionalSharedHistory] removeAllItems];
            break;

        case NSAlertSecondButtonReturn:
        default:
            break;
    }
}

@end
