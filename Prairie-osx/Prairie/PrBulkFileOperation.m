/*!
    @file
    @brief Definition of a multi-file opening operation class.
    @details An operation sets up and completes a call from the app delegate's application:openFiles: method.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrBulkFileOperation.h"
#import "PrairieAppDelegate.h"
#import "PrBrowserController.h"


#pragma mark Private interface

@interface PrBulkFileOperation () {
    NSMutableSet  *_cancelledFiles, *_failedFiles, *_successfulFiles;
}

@property (readonly) NSSet                *cancelledFiles;
@property (readonly) NSMutableSet  *mutableCancelledFiles;
@property (readonly) NSSet                *failedFiles;
@property (readonly) NSMutableSet  *mutableFailedFiles;
@property (readonly) NSSet                *successfulFiles;
@property (readonly) NSMutableSet  *mutableSuccessfulFiles;

@property NSMutableDictionary *  fileFromBrowser;

- (instancetype)initWithFiles:(NSArray *)paths application:(NSApplication *)app printSettings:(NSDictionary *)info printPanel:(BOOL)showPanel;

- (PrBrowserController *)createBrowserForFile:(NSURL *)file visible:(BOOL)visibility;
- (void)connectNotificationsForBrowser:(PrBrowserController *)browser;
- (void)disconnectNotificationsForBrowser:(PrBrowserController *)browser onlyLoadingNotifications:(BOOL)loading;

- (void)commonNotifyOnBrowser:(NSNotification *)notification status:(NSMutableSet *)statusSet browserController:(PrBrowserController *)browser;
- (void)notifyOnBrowserWindowClose:(NSNotification *)notification;
- (void)notifyOnBrowserLoadFail:(NSNotification *)notification;
- (void)notifyOnBrowserLoadSucceed:(NSNotification *)notification;
- (void)notifyOnBrowserPrintFail:(NSNotification *)notification;
- (void)notifyOnBrowserPrintSucceed:(NSNotification *)notification;

@end

@implementation PrBulkFileOperation

#pragma mark Factory methods

/*!
    @brief Factory method for the application delegate to open file(s).
    @param paths The files to be opened. Elements are NSString objects, each representing its file's path.
    @param app The application object that wants the files opened.
    @details Calls the initializer, creates a browser window for each file, sets up connections between the instance and each browser, and adds the instance to [NSOperationQueue mainQueue], which calls [app replyToOpenOrPrint:X], where X is the completion status.

    Call from the application delegate's application:openFiles: method.
    @return The instance doing the actions, or nil if initialization failed.
 */
+(instancetype)openFiles:(NSArray *)paths application:(NSApplication *)app {
    PrBulkFileOperation * const  actor = [[self alloc] initWithFiles:paths application:app printSettings:nil printPanel:NO];

    if (actor) {
        for (NSURL *file in actor.files) {
            (void)[actor createBrowserForFile:file visible:YES];
        }
        [[NSOperationQueue mainQueue] addOperation:actor];
    }
    return actor;
}

/*!
    @brief Factory method for the application delegate to print file(s).
    @param paths The files to be printed. Elements are NSString objects, each representing its file's path.
    @param app The application object that wants the files printed.
    @param info The parameters for the print job.
    @param showPrintPanel YES to give the user a change to adjust the Print panel, NO to skip the panel. (The progress panel is always shown.)
    @details Calls the initializer, creates a browser window for each file, sets up connections between the instance and each browser, and adds the instance to [NSOperationQueue mainQueue], which calls [app replyToOpenOrPrint:X], where X is the completion status.
 
    Call from the application delegate's application:printFiles:withSettings:showPrintPanels: method.
    @return The instance doing the actions, or nil if initialization failed.

 */
+(instancetype)printFiles:(NSArray *)paths application:(NSApplication *)app settings:(NSDictionary *)info panel:(BOOL)showPrintPanel {
    PrBulkFileOperation * const  actor = [[self alloc] initWithFiles:paths application:app printSettings:info printPanel:showPrintPanel];
    
    if (actor) {
        for (NSURL *file in actor.files) {
            (void)[actor createBrowserForFile:file visible:YES];
        }
        [[NSOperationQueue mainQueue] addOperation:actor];
    }
    return actor;
}

#pragma mark Initialization

/*!
    @brief Designated initializer
    @param paths The files to be opened. Elements are NSString objects each representing its file's path.
    @param app The application object that wants the files opened.
    @param info The print job parameters. Set to nil for non-printing opens.
    @param showPanel YES to show the Print panel before printing, NO otherwise, ignored for non-printing opens.
    @details Only records the arguments into self's properties, converting the file paths into URLs and the dictionary into a print-job parameter block. Does not initiate the opening procedure.
    @return The generated instance, or nil if something failed.
 */
- (instancetype)initWithFiles:(NSArray *)paths application:(NSApplication *)app printSettings:(NSDictionary *)info printPanel:(BOOL)showPanel {
    if (self = [super init]) {
        NSMutableArray * const  urls = [[NSMutableArray alloc] initWithCapacity:paths.count];

        for (NSString *path in paths) {
            NSURL * const  url = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]];

            if (url) {
                [urls addObject:url];
            } else {
                return nil;
            }
        }
        if (!(_files = [[NSArray alloc] initWithArray:urls]) || !(_cancelledFiles = [[NSMutableSet alloc] initWithCapacity:paths.count]) || !(_failedFiles = [[NSMutableSet alloc] initWithCapacity:paths.count]) || !(_successfulFiles = [[NSMutableSet alloc] initWithCapacity:paths.count]) || !(_fileFromBrowser = [[NSMutableDictionary alloc] initWithCapacity:paths.count])) {
            return nil;
        }
        _application = app;
        if (info) {
            if (!(_printSettings = [[NSPrintInfo alloc] initWithDictionary:info])) {
                return nil;
            }
        } else {
            _printSettings = nil;
        }
        _displayPrintPanel = showPanel;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Property getters & setters

@synthesize cancelledFiles  = _cancelledFiles;
@synthesize failedFiles     = _failedFiles;
@synthesize successfulFiles = _successfulFiles;

- (void)addCancelledFilesObject:(NSURL *)file {
    [_cancelledFiles addObject:file];
}

- (void)removeCancelledFilesObject:(NSURL *)file {
    [_cancelledFiles removeObject:file];
}

- (NSMutableSet *)mutableCancelledFiles {
    return [self mutableSetValueForKey:@"cancelledFiles"];
}

- (void)addFailedFilesObject:(NSURL *)file {
    [_failedFiles addObject:file];
}

- (void)removeFailedFilesObject:(NSURL *)file {
    [_failedFiles removeObject:file];
}

- (NSMutableSet *)mutableFailedFiles {
    return [self mutableSetValueForKey:@"failedFiles"];
}

- (void)addSuccessfulFilesObject:(NSURL *)file {
    [_successfulFiles addObject:file];
}

- (void)removeSuccessfulFilesObject:(NSURL *)file {
    [_successfulFiles removeObject:file];
}

- (NSMutableSet *)mutableSuccessfulFiles {
    return [self mutableSetValueForKey:@"successfulFiles"];
}

- (NSUInteger)handledCount {
    return self.cancelledFiles.count + self.failedFiles.count + self.successfulFiles.count;
}

#pragma mark KVO management

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *  keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

    if ([key isEqualToString:NSStringFromSelector(@selector(isReady))]) {
        keyPaths = [keyPaths setByAddingObject:NSStringFromSelector(@selector(handledCount))];
    } else if ([key isEqualToString:NSStringFromSelector(@selector(handledCount))]) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:@[@"cancelledFiles", @"failedFiles", @"successfulFiles"]];
    }
    return keyPaths;
}

#pragma mark Browser creation and connection

/*!
    @brief Creates a browser window to load the given file.
    @param file The file to be opened. Must be an element of self.files.
    @param visibility Whether or not the window is made visible. Use NO for secret transactions.
    @details Also sets up the various connections for observing the browser's state.
    @return The browser window's controller, or nil if its creation failed.
 */
- (PrBrowserController *)createBrowserForFile:(NSURL *)file visible:(BOOL)visibility {
    id const  browser = [[NSApp delegate] createBrowser];

    if (browser) {
        [self.fileFromBrowser setObject:file forKey:[NSValue valueWithPointer:(__bridge const void *)browser]];
        [self connectNotificationsForBrowser:browser];
        if (visibility) {
            [browser showWindow:self.application];
        }
        [browser loadPage:file];
    } else {
        [self.mutableFailedFiles addObject:file];
    }
    return browser;
}

/*!
    @brief Add the notifications from the browser window to this operation.
    @param browser The window controller (and matching window) to exchange notifications.
 */
- (void)connectNotificationsForBrowser:(PrBrowserController *)browser {
    NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

    [notifier addObserver:self selector:@selector(notifyOnBrowserWindowClose:) name:NSWindowWillCloseNotification object:browser.window];
    [notifier addObserver:self selector:@selector(notifyOnBrowserLoadFail:) name:PrBrowserLoadFailedNotification object:browser];
    [notifier addObserver:self selector:@selector(notifyOnBrowserLoadSucceed:) name:PrBrowserLoadPassedNotification object:browser];
}

/*!
    @brief Remove the notifications from the browser window to this operation.
    @param browser The window controller (and matching window) to exchange notifications.
    @param loading NO to remove all notifications, YES to only remove the ones for resource loading.
 */
- (void)disconnectNotificationsForBrowser:(PrBrowserController *)browser onlyLoadingNotifications:(BOOL)loading {
    NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

    [notifier removeObserver:self name:PrBrowserLoadPassedNotification object:browser];
    [notifier removeObserver:self name:PrBrowserLoadFailedNotification object:browser];
    if (!loading) {
        [notifier removeObserver:self name:PrBrowserPrintPassedNotification object:browser];
        [notifier removeObserver:self name:PrBrowserPrintFailedNotification object:browser];
        [notifier removeObserver:self name:NSWindowWillCloseNotification object:browser.window];
    }
}

#pragma mark Notifications

/*!
    @brief Common notification method code.
    @param notification The sent notification.
    @param statusSet The mutable-set corresponding to the status the file ends up getting.
    @param browser The browser window's controller.
    @details Removes the given window and its controller from tracking.
 */
- (void)commonNotifyOnBrowser:(NSNotification *)notification status:(NSMutableSet *)statusSet browserController:(PrBrowserController *)browser {
    NSValue * const  browserPointer = [NSValue valueWithPointer:(__bridge const void *)browser];

    [self disconnectNotificationsForBrowser:browser onlyLoadingNotifications:NO];
    [statusSet addObject:self.fileFromBrowser[browserPointer]];
    [self.fileFromBrowser removeObjectForKey:browserPointer];  // The key would be a dangling pointer after the window closes.
}

/*!
    @brief Response to NSWindowWillCloseNotification.
    @param notification The sent notification.
    @details Does common clean up and considers the processing of its file to be cancelled.
 */
- (void)notifyOnBrowserWindowClose:(NSNotification *)notification {
    [self commonNotifyOnBrowser:notification status:self.mutableCancelledFiles browserController:[notification.object windowController]];
}

/*!
    @brief Response to PrBrowserLoadFailedNotification.
    @param notification The sent notification.
    @details Does common clean up and considers the loading of its file to have failed.
 */
- (void)notifyOnBrowserLoadFail:(NSNotification *)notification {
    [self commonNotifyOnBrowser:notification status:self.mutableFailedFiles browserController:notification.object];
}

/*!
    @brief Response to PrBrowserLoadPassedNotification.
    @param notification The sent notification.
    @details Considers the loading of its file to have succeeded. If printing, does more setup and sends out the print request. Does the appropriate amount of common cleanup.
 */
- (void)notifyOnBrowserLoadSucceed:(NSNotification *)notification {
    id const  browser = notification.object;

    if (self.printSettings) {
        NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

        [self disconnectNotificationsForBrowser:browser onlyLoadingNotifications:YES];
        [notifier addObserver:self selector:@selector(notifyOnBrowserPrintFail:) name:PrBrowserPrintFailedNotification object:browser];
        [notifier addObserver:self selector:@selector(notifyOnBrowserPrintSucceed:) name:PrBrowserPrintPassedNotification object:browser];
        [browser printWithInfo:self.printSettings showPrint:self.displayPrintPanel showProgress:YES];
    } else {
        [self commonNotifyOnBrowser:notification status:self.mutableSuccessfulFiles browserController:browser];
    }
}

/*!
    @brief Response to PrBrowserPrintFailedNotification.
    @param notification The sent notification.
    @details Does common clean up and considers the printing of its file to have failed.
 */
- (void)notifyOnBrowserPrintFail:(NSNotification *)notification {
    [self commonNotifyOnBrowser:notification status:self.mutableFailedFiles browserController:notification.object];
}

/*!
    @brief Response to PrBrowserPrintPassedNotification.
    @param notificiation The sent notification.
    @details Does common clean up and considers the printing of its file to have succeeded.
 */
- (void)notifyOnBrowserPrintSucceed:(NSNotification *)notification{
    [self commonNotifyOnBrowser:notification status:self.mutableSuccessfulFiles browserController:notification.object];
}

#pragma mark Conventional overrides

- (BOOL)isReady {
    return [super isReady] && (self.handledCount >= self.files.count);
}

- (void)main {
    NSApplicationDelegateReply  result = NSApplicationDelegateReplyCancel;

    if (!self.isCancelled && !self.cancelledFiles.count) {
        result = NSApplicationDelegateReplySuccess;
        if (self.failedFiles.count) {
            result = NSApplicationDelegateReplyFailure;
        }
    }
    [self.application replyToOpenOrPrint:result];
}

@end
