/*!
    @file
    @brief Definition of a multi-file opening (and printing) management class.
    @details An operation sets up and completes a call from the app delegate's application:openFiles: or application:printFiles:withSettings:showPrintPanels: methods.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrFileOpener.h"
#import "PrairieAppDelegate.h"
#import "PrBrowserController.h"


#pragma mark Private interface

@interface PrFileOpener ()

- (void)notifyFromWindow:(NSNotification *)note;
- (void)notifyOnLoadFail:(NSNotification *)note;
- (void)notifyOnLoadSuccess:(NSNotification *)note;
- (void)notifyOnPrintFail:(NSNotification *)note;
- (void)notifyOnPrintSuccess:(NSNotification *)note;

- (BOOL)takeBrowser:(id)browser fromPool:(NSMutableSet *)pool;
- (void)checkFinished;

@property (nonatomic, assign) NSUInteger  fails, cancels, successes;  // counters
@property (nonatomic) NSMutableSet        *openSpool, *printSpool;    // file-handling management

@property (nonatomic, readwrite, assign) BOOL  finished;  // Made writable here to trigger KVO.

@end

@implementation PrFileOpener

#pragma mark Initialization

// See the header for details.
- (instancetype)initWithFiles:(NSArray *)paths application:(NSApplication *)app {
    if (self = [super init]) {
        NSMutableArray * const  convertedPaths = [[NSMutableArray alloc] initWithCapacity:paths.count];

        if (!convertedPaths) {
            return nil;
        }
        if (!(_openSpool = [[NSMutableSet alloc] initWithCapacity:paths.count])) {
            return nil;
        }
        if (!(_printSpool = [[NSMutableSet alloc] initWithCapacity:paths.count])) {
            return nil;
        }
        _fails = _cancels = _successes = 0u;
        _application = app;
        for (NSString *path in paths) {
            NSURL * const  url = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]];

            if (url) {
                [convertedPaths addObject:url];
            } else {
                ++_fails;
            }
        }
        _files = convertedPaths;
        _finished = NO;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Notifications

/*!
    @brief Response to NSWindowWillCloseNotification.
    @param note The sent notification.
    @details Checks both the open and print spools for affected files. A closed file represents a cancelled open/print.
 */
- (void)notifyFromWindow:(NSNotification *)note {
    // At most one of the following two lines should do something.
    self.cancels += !![self takeBrowser:[note.object windowController] fromPool:self.openSpool];
    self.cancels += !![self takeBrowser:[note.object windowController] fromPool:self.printSpool];
    [self checkFinished];
}

/*!
    @brief Response to PrBrowserLoadFailedNotification.
    @param note The sent notification.
    @details Checks the open spool for affected files. A loading failure marks its file as failed.
 */
- (void)notifyOnLoadFail:(NSNotification *)note {
    self.fails += !![self takeBrowser:note.object fromPool:self.openSpool];
    [self checkFinished];
}

/*!
    @brief Response to PrBrowserLoadPassedNotification.
    @param note The sent notification.
    @details Checks to open spool for affected files. If just opening, the file is marked as successful and any search string is applied. Otherwise, the file is moved to the print spool and the print action is sent on the next run loop.
 */
- (void)notifyOnLoadSuccess:(NSNotification *)note {
    if ([self takeBrowser:note.object fromPool:self.openSpool]) {
        if (self.settings) {  // Hopefully, checkFinished won't be called between the above and below lines.
            [self.printSpool addObject:note.object];
        } else {
            ++self.successes;
            [self checkFinished];
        }
    }
}

/*!
    @brief Response to PrBrowserPrintFailedNotification.
    @param note The sent notification.
    @details Checks the print spool for affected files. A printing failure marks its file as failed.
 */
- (void)notifyOnPrintFail:(NSNotification *)note {
    self.fails += !![self takeBrowser:note.object fromPool:self.printSpool];
    [self checkFinished];
}

/*!
    @brief Response to PrBrowserPrintPassedNotification.
    @param note The sent notification.
    @details Checks the print spool for affected files. The file is marked as successful.
 */
- (void)notifyOnPrintSuccess:(NSNotification *)note {
    self.successes += !![self takeBrowser:note.object fromPool:self.printSpool];
    [self checkFinished];
}

#pragma mark Operations

/*!
    @brief Removes the targeted browser from the given processing pool.
    @param browser The targeted PrBrowserController instance.
    @param pool The targeted pool.
    @return Whether the browser was in the pool (YES), or was absent (NO).
 */
- (BOOL)takeBrowser:(id)browser fromPool:(NSMutableSet *)pool {
    BOOL const  present = [pool containsObject:browser];

    if (present) {
        [pool removeObject:browser];
    }
    return present;
}

/*!
    @brief Completion routine.
    @details If there are no more files to process, send the system open/print completion flag and set this instance's completion flag. (The latter is KVO'd, so observers can act on it.)
 */
- (void)checkFinished {
    if (!self.finished && !self.openSpool.count && !self.printSpool.count) {
        [self.application replyToOpenOrPrint:(self.cancels ? NSApplicationDelegateReplyCancel : self.fails ? NSApplicationDelegateReplyFailure : NSApplicationDelegateReplySuccess)];
        self.finished = YES;
    }
}

// See the header for details.
- (void)start {
    NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

    // The notifications are global (relative to this instance) so I don't have to do a bunch of individual removals everytime a file is handled (successfully or not). A long as nothing else messes with a file-browser while this instance is around, my state machine won't get messed up.
    [notifier addObserver:self selector:@selector(notifyFromWindow:) name:NSWindowWillCloseNotification object:nil];
    [notifier addObserver:self selector:@selector(notifyOnLoadFail:) name:PrBrowserLoadFailedNotification object:nil];
    [notifier addObserver:self selector:@selector(notifyOnLoadSuccess:) name:PrBrowserLoadPassedNotification object:nil];
    [notifier addObserver:self selector:@selector(notifyOnPrintFail:) name:PrBrowserPrintFailedNotification object:nil];
    [notifier addObserver:self selector:@selector(notifyOnPrintSuccess:) name:PrBrowserPrintPassedNotification object:nil];

    for (NSURL *file in self.files) {
        PrBrowserController * const  browser = [(PrairieAppDelegate *)[self.application delegate] createBrowser];

        if (browser) {
            [self.openSpool addObject:browser];
            [browser showWindow:self.application];
            [browser loadPage:file title:nil searching:self.search printing:self.settings showPrint:self.showPrintPanel showProgress:YES];
        } else {
            ++self.fails;
        }
    }
    [self checkFinished];  // Just in case there were no files or all of them failed initialization.
}

@end
