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
#import "PrHistoricMenus.h"
#import "PrUserDefaults.h"
#import "PrServicesProvider.h"

@import ApplicationServices;
@import CoreServices;
@import WebKit;


#pragma mark File-local constants

static NSString * const  keyPathFinished = @"finished";  // from PrFileOpener

static NSString * const    PrHistoryFilenameV1 = @"History";
#define PrHistoryFilename  PrHistoryFilenameV1  // Can't point to another NSString and stay a compile-time constant.

// Number of seconds after the WebHistory object is dirtied that a saving action is sent. Other dirtying events within the time window do not trigger more delayed saves.
static NSTimeInterval const  PrHistoryChangeSaveDelay = 60.0;

// A unique context to use for the KVO functions. Needed for advanced KVO to differentiate between use by different classes of a hierarchy.
static void * const  PrivateKVOContext = (void *)&PrivateKVOContext;

#pragma mark Private interface

@interface PrairieAppDelegate () {
    NSMutableSet *  _windowControllers;
}

/*!
    @brief Load the user's History file.
    @details If the 'defaults.loadSaveHistory' nested property is NO, does nothing. Otherwise, loads the cached WebHistory store from a file location stored as bookmark data in another property. Updates bookmark data as needed.
 */
- (void)recallHistory;
/*!
    @brief Save the user's History file.
    @details If the 'defaults.loadSaveHistory' nested property is NO, does nothing. Otherwise saves the WebHistory store to a cache file, whose location is either stored as bookmark data in another property or will be stored there once the file is created at a default URL.
 */
- (void)preserveHistory;
/*!
    @brief Connects 'todayHistoryHandler' to the appropriate per-day WebHistoryItem menu.
    @details If there's a menu item (and submenu) for today, connect it to 'todayHistoryHandler' and then hide it.
 */
- (void)prepareTodayHistoryMenu;
/*!
    @brief Add and update the WebHistory-day menus.
    @param change A KVO-oriented description of the changes to the history menus.
    @details Adds the menu items after the "Earlier Today" submenu.
 */
- (void)rebuildHistoryMenusDueToChange:(NSDictionary *)change;
/*!
    @brief Add and update the most recent WebHistory menu items for Today directly in the Browse menu.
    @param change A KVO-oriented description of the changes to the history menu section.
    @details Adds/updates/removes the menu items between the "History" header and "Earlier Today" submenu.
 */
- (void)rebuildTodayDirectHistoryMenuDueToChange:(NSDictionary *)change;
/*!
    @brief Add and update the non-recent WebHistory menu items for Today in the Browse menu's "Earlier Today" submenu.
    @param change A KVO-oriented description of the changes to a history menu subsection.
    @details Adds/updates/removes the menu items in the "Earlier Today" submenu.
 */
- (void)rebuildTodayOverflowHistoryMenuDueToChange:(NSDictionary *)change;

- (void)notifyOnWindowClose:(NSNotification *)notification;
/*!
    @brief Response to NSCalendarDayChangedNotification.
    @param notification The sent notification.
    @details Resets what 'todayHistoryHandler' points to.
 */
- (void)notifyOnNewDay:(NSNotification *)notification;

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply;

@property (nonatomic, readonly) NSMutableSet *     mutableWindowControllers;  // Mutable reference to windowControllers.
@property (nonatomic, readonly) NSMutableSet *     openFilers;  // Holds processors so ARC won't claim them early.
@property (nonatomic, readonly, copy) NSURL *      defaultHistoryFileURL;  // Default location for the History file.
@property (nonatomic, readonly) PrHistoricMenus *  menuHistorian;  // Handles History menu updates.
//! Centralized access point for user defaults.
@property (nonatomic, readonly) PrUserDefaults *   defaults;

@end

@implementation PrairieAppDelegate

#pragma mark Initialization

- (instancetype)init {
    if (self = [super init]) {
        WebHistory * const  history = [[WebHistory alloc] init];

        _windowControllers = [[NSMutableSet alloc] init];
        _openFilers = [[NSMutableSet alloc] init];
        _menuHistorian = [[PrHistoricMenus alloc] initWithHistory:history];
        _todayHistoryHandler = [[PrOverflowingMenu alloc] init];
        _defaults = [PrUserDefaults sharedInstance];
        if (history && _windowControllers && _openFilers && _menuHistorian && _todayHistoryHandler && _defaults) {
            [WebHistory setOptionalSharedHistory:history];
        } else {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Property getters & setters

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
        [opener addObserver:self forKeyPath:keyPathFinished options:NSKeyValueObservingOptionNew context:PrivateKVOContext];
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
        [printer addObserver:self forKeyPath:keyPathFinished options:NSKeyValueObservingOptionNew context:PrivateKVOContext];
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
    if (self.defaults.openUntitledToDefaultPage) {
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
    [PrUserDefaults setup];

    // Open remote URLs
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:replyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    // Perliminaries to using app-global web-history.
    (void)[[NSFileManager defaultManager] createDirectoryAtURL:self.applicationSupportDirectory withIntermediateDirectories:YES attributes:nil error:nil];  // WebHistory's -saveToURL:error: won't create intermediate directories.
    self.todayHistoryHandler.maxDirectCount = self.defaults.maxTodayHistoryMenuLength;

    // Use app-global web-history. Must happen in the order given.
    [self.menuHistorian addObserver:self forKeyPath:PrKeyPathDayMenuItems options:NSKeyValueObservingOptionNew context:PrivateKVOContext];
    [self.menuHistorian addObserver:self forKeyPath:PrKeyPathNeedsSaving options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:PrivateKVOContext];
    [self.todayHistoryHandler addObserver:self forKeyPath:PrKeyPathDirectMenuItems options:NSKeyValueObservingOptionNew context:PrivateKVOContext];
    [self.todayHistoryHandler addObserver:self forKeyPath:PrKeyPathOverflowMenuItems options:NSKeyValueObservingOptionNew context:PrivateKVOContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyOnNewDay:) name:NSCalendarDayChangedNotification object:nil];
    [self recallHistory];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Set up Services.
    [NSApp setServicesProvider:[PrServicesProvider new]];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // Use app-global web-history. Must happen in the order given (the reverse of the finish-launching handler).
    [self preserveHistory];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSCalendarDayChangedNotification object:nil];
    [self.todayHistoryHandler removeObserver:self forKeyPath:PrKeyPathOverflowMenuItems context:PrivateKVOContext];
    [self.todayHistoryHandler removeObserver:self forKeyPath:PrKeyPathDirectMenuItems context:PrivateKVOContext];
    [self.menuHistorian removeObserver:self forKeyPath:PrKeyPathNeedsSaving context:PrivateKVOContext];
    [self.menuHistorian removeObserver:self forKeyPath:PrKeyPathDayMenuItems context:PrivateKVOContext];
}

#pragma mark NSKeyValueObserving override

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id const  newValue = change[NSKeyValueChangeNewKey];
    id const  oldValue = change[NSKeyValueChangeOldKey];

    if (PrivateKVOContext != context) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }

    if ([self.openFilers containsObject:object] && [keyPath isEqualToString:keyPathFinished]) {
        NSParameterAssert(newValue && [newValue isKindOfClass:[NSNumber class]]);
        if ([newValue boolValue]) {
            [object removeObserver:self forKeyPath:keyPathFinished context:context];
            [self.openFilers removeObject:object];
        }
    } else if ((self.menuHistorian == object) && [keyPath isEqualToString:PrKeyPathDayMenuItems]) {
        [self rebuildHistoryMenusDueToChange:change];
    } else if ((self.menuHistorian == object) && [keyPath isEqualToString:PrKeyPathNeedsSaving]) {
        NSParameterAssert(newValue && [newValue isKindOfClass:[NSNumber class]]);
        NSParameterAssert(oldValue && [oldValue isKindOfClass:[NSNumber class]]);
        if (![oldValue boolValue] && [newValue boolValue]) {
            // Web-history is dirty; save it soon, but suspend sudden-termination until then.
            [[NSProcessInfo processInfo] disableSuddenTermination];
            [self performSelector:@selector(preserveHistory) withObject:nil afterDelay:PrHistoryChangeSaveDelay];
        } else if ([oldValue boolValue] && ![newValue boolValue]) {
            // Web-history just became undirty; allow sudden-termination again.
            [[NSProcessInfo processInfo] enableSuddenTermination];
        }
    } else if ((self.todayHistoryHandler == object) && [keyPath isEqualToString:PrKeyPathDirectMenuItems]) {
        [self rebuildTodayDirectHistoryMenuDueToChange:change];
    } else if ((self.todayHistoryHandler == object) && [keyPath isEqualToString:PrKeyPathOverflowMenuItems]) {
        [self rebuildTodayOverflowHistoryMenuDueToChange:change];
    }
}

#pragma mark NSMenuValidation override

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL const  action = [menuItem action];
    
    if (action == @selector(validateHistory:)) {
        menuItem.title = [WebHistory optionalSharedHistory].orderedLastVisitedDays.count ? NSLocalizedString(@"HISTORY_STORE_NONEMPTY", nil) : NSLocalizedString(@"HISTORY_STORE_EMPTY", nil);
        return self.defaults.useValidateHistoryMenuItem;
    }
    return YES;
}

#pragma mark Private methods, history management

// See private interface for details.
- (void)recallHistory {
    if (!self.defaults.loadSaveHistory) return;  // Respect the preference for having an external copy.

    BOOL          stale = NO;
    NSError *     error = nil;
    NSURL *  historyURL = [NSURL URLByResolvingBookmarkData:self.defaults.historyFileBookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];

    if (historyURL) {
        if (stale) {
            NSData * const  newBookmark = [historyURL bookmarkDataWithOptions:kNilOptions includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

            if (newBookmark) {
                self.defaults.historyFileBookmark = newBookmark;
            }
        }

        (void)[[WebHistory optionalSharedHistory] loadFromURL:historyURL error:&error];
    }
}

// See private interface for details.
- (void)preserveHistory {
    if (!self.defaults.loadSaveHistory) return;  // Respect the preference for having an external copy.

    BOOL       stale = NO;
    NSError *  error = nil;
    NSURL *    historyURL = [NSURL URLByResolvingBookmarkData:self.defaults.historyFileBookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];

    if (historyURL) {
        if (stale) {
            NSData * const  newBookmark = [historyURL bookmarkDataWithOptions:kNilOptions includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            
            if (newBookmark) {
                self.defaults.historyFileBookmark = newBookmark;
            }
        }
        stale = NO;  // repurpose to indicate bookmark data does not need to be (re)calculated.
    } else {
        historyURL = self.defaultHistoryFileURL;
        stale = YES;  // repurpose to indicate bookmark data needs to be (re)calculated.
    }

    if ([[WebHistory optionalSharedHistory] saveToURL:historyURL error:&error]) {
        if (stale) {
            self.defaults.historyFileBookmark = [historyURL bookmarkDataWithOptions:kNilOptions includingResourceValuesForKeys:nil relativeToURL:nil error:&error];  // If creating bookmark fails, try again next session.
        }
    }
}

// See private interface for details.
- (void)prepareTodayHistoryMenu {
    NSMenu * const  browseMenu = self.earlierToday.menu;
    NSInteger       earlierTodayIndex = [browseMenu indexOfItem:self.earlierToday];
    NSMenuItem *    menuItem;

    NSParameterAssert(browseMenu);
    NSParameterAssert(earlierTodayIndex != -1);
    while ((menuItem = [browseMenu itemAtIndex:++earlierTodayIndex]) && !menuItem.isSeparatorItem) {
        if ([[NSCalendar autoupdatingCurrentCalendar] isDateInToday:menuItem.representedObject]) {
            break;
        }
    }
    if (!menuItem || menuItem.isSeparatorItem) {
        self.todayHistoryHandler.sourceMenu = nil;
    } else if (self.todayHistoryHandler.sourceMenu != menuItem.submenu) {
        self.todayHistoryHandler.sourceMenu = menuItem.submenu;
    }
}

// See private interface for details.
- (void)rebuildHistoryMenusDueToChange:(NSDictionary *)change {
    NSMenu * const          browseMenu = self.earlierToday.menu;
    NSInteger  beyondEarlierTodayIndex = [browseMenu indexOfItem:self.earlierToday] + 1;
    NSKeyValueChange const  changeType = (NSKeyValueChange)[change[NSKeyValueChangeKindKey] unsignedIntegerValue];
    NSIndexSet * const  indexesChanged = change[NSKeyValueChangeIndexesKey];  // May be nil, depending on 'changeType'.

    NSParameterAssert(browseMenu);
    NSParameterAssert(beyondEarlierTodayIndex != -1 + 1);
    switch (changeType) {
        default:
        case NSKeyValueChangeSetting: {
            // Do wholesale replacement; get rid of the current menu items and install the new ones.
            while (![browseMenu itemAtIndex:beyondEarlierTodayIndex].isSeparatorItem) {
                [browseMenu removeItemAtIndex:beyondEarlierTodayIndex];
            }
            for (NSMenuItem *item in self.menuHistorian.dayMenuItems) {
                [browseMenu insertItem:item atIndex:beyondEarlierTodayIndex++];
            }
            beyondEarlierTodayIndex = [browseMenu indexOfItem:self.earlierToday] + 1;
            [self prepareTodayHistoryMenu];  // Rebuild today's history menus.
            break;
        }

        case NSKeyValueChangeRemoval: {
            // Purge the menus of the deleted indexes.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
                [browseMenu removeItemAtIndex:(beyondEarlierTodayIndex + (NSInteger)idx)];
            }];
            if ([indexesChanged containsIndex:0u]) {  // Only if today was deleted,...
                [self prepareTodayHistoryMenu];  // ...rebuild today's history menus.
            }
            break;
        }
            
        case NSKeyValueChangeInsertion: {
            // Place the menus of the added indexes.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                [browseMenu insertItem:self.menuHistorian.dayMenuItems[idx] atIndex:(beyondEarlierTodayIndex + (NSInteger)idx)];
            }];
            if ([indexesChanged containsIndex:0u]) {  // Gained or still have a today menu item, so just update.
                [self prepareTodayHistoryMenu];
            }
            break;
        }

        case NSKeyValueChangeReplacement: {
            // Since NSMenu doesn't have a replacement API, do a removal & insert.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                NSInteger const  location = beyondEarlierTodayIndex + (NSInteger)idx;

                [browseMenu removeItemAtIndex:location];
                [browseMenu insertItem:self.menuHistorian.dayMenuItems[idx] atIndex:location];
            }];
            if ([indexesChanged containsIndex:0u]) {  // Still have a today menu item, so just update.
                [self prepareTodayHistoryMenu];
            }
            break;
        }
    }
}

// See private interface for details.
- (void)rebuildTodayDirectHistoryMenuDueToChange:(NSDictionary *)change {
    NSMenu * const          browseMenu = self.historyHeader.menu;
    NSInteger       beyondHistoryIndex = [browseMenu indexOfItem:self.historyHeader] + 1;
    NSKeyValueChange const  changeType = (NSKeyValueChange)[change[NSKeyValueChangeKindKey] unsignedIntegerValue];
    NSIndexSet * const  indexesChanged = change[NSKeyValueChangeIndexesKey];  // May be nil, depending on 'changeType'.

    NSParameterAssert(browseMenu);
    NSParameterAssert(beyondHistoryIndex != -1 + 1);
    switch (changeType) {
        default:
        case NSKeyValueChangeSetting: {
            // Do wholesale replacement; get rid of the current menu items and install the new ones.
            NSMenuItem * const  earlierTodayMenuItem = self.earlierToday;

            while ([browseMenu itemAtIndex:beyondHistoryIndex] != earlierTodayMenuItem) {
                [browseMenu removeItemAtIndex:beyondHistoryIndex];
            }
            for (NSMenuItem *item in self.todayHistoryHandler.directMenuItems) {
                [browseMenu insertItem:item atIndex:beyondHistoryIndex++];
            }
            beyondHistoryIndex = [browseMenu indexOfItem:self.historyHeader] + 1;
            break;
        }

        case NSKeyValueChangeRemoval: {
            // Purge the menus of the deleted indexes.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
                [browseMenu removeItemAtIndex:(beyondHistoryIndex + (NSInteger)idx)];
            }];
            break;
        }

        case NSKeyValueChangeInsertion: {
            // Place the menus of the added indexes.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                [browseMenu insertItem:self.todayHistoryHandler.directMenuItems[idx] atIndex:(beyondHistoryIndex + (NSInteger)idx)];
            }];
            break;
        }

        case NSKeyValueChangeReplacement: {
            // Since NSMenu doesn't have a replacement API, do a removal & insert.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                NSInteger const  location = beyondHistoryIndex + (NSInteger)idx;
                
                [browseMenu removeItemAtIndex:location];
                [browseMenu insertItem:self.todayHistoryHandler.directMenuItems[idx] atIndex:location];
            }];
            break;
        }
    }
}

// See private interface for details.
- (void)rebuildTodayOverflowHistoryMenuDueToChange:(NSDictionary *)change {
    NSMenu * const    earlierTodayMenu = self.earlierToday.submenu;
    NSKeyValueChange const  changeType = (NSKeyValueChange)[change[NSKeyValueChangeKindKey] unsignedIntegerValue];
    NSIndexSet * const  indexesChanged = change[NSKeyValueChangeIndexesKey];  // May be nil, depending on 'changeType'.

    NSParameterAssert(earlierTodayMenu);
    switch (changeType) {
        default:
        case NSKeyValueChangeSetting: {
            // Do wholesale replacement; get rid of the current menu items and install the new ones.
            [earlierTodayMenu removeAllItems];
            for (NSMenuItem *item in self.todayHistoryHandler.overflowMenuItems) {
                [earlierTodayMenu addItem:item];
            }
            break;
        }

        case NSKeyValueChangeRemoval: {
            // Purge the menus of the deleted indexes.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
                [earlierTodayMenu removeItemAtIndex:(NSInteger)idx];
            }];
            break;
        }

        case NSKeyValueChangeInsertion: {
            // Place the menus of the added indexes.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                [earlierTodayMenu insertItem:self.todayHistoryHandler.overflowMenuItems[idx] atIndex:(NSInteger)idx];
            }];
            break;
        }

        case NSKeyValueChangeReplacement: {
            // Since NSMenu doesn't have a replacement API, do a removal & insert.
            NSParameterAssert(indexesChanged);
            [indexesChanged enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                [earlierTodayMenu removeItemAtIndex:(NSInteger)idx];
                [earlierTodayMenu insertItem:self.todayHistoryHandler.overflowMenuItems[idx] atIndex:(NSInteger)idx];
            }];
            break;
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

// See private interface for details.
- (void)notifyOnNewDay:(NSNotification *)notification {
    [self prepareTodayHistoryMenu];
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
        [handler addObserver:self forKeyPath:keyPathFinished options:NSKeyValueObservingOptionNew context:PrivateKVOContext];
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

// See header for details.
- (IBAction)revisitHistory:(id)sender {
    PrBrowserController * const  browser = [self createBrowser];
    
    [browser showWindow:sender];
    [browser revisitHistory:sender];
}

@end
