/*!
    @file
    @brief Definition of a URL-displaying operation class.
    @details An operation sets up and completes the handling of a Get-URL Apple event.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrGetURLOperation.h"
#import "PrBrowserController.h"
#import "PrairieAppDelegate.h"

@import CoreServices;


#pragma mark File-local types

typedef enum : NSUInteger {
    loadUnstarted,
    loadCancelled,
    loadSucceeded,
    loadFailed,
} loadStatus;

#pragma mark Private interface

@interface PrGetURLOperation ()

@property NSURL *                    url;
@property loadStatus              status;
@property PrBrowserController *  browser;
@property NSError *              problem;

- (instancetype)initWithEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply;

- (void)setupBrowser;
- (void)connectNotificationsForBrowser;
- (void)notifyOnCompletion:(NSNotification *)notification;

@end


@implementation PrGetURLOperation

/*!
    @brief Factory method for the application delegate to open a URL.
    @param event The URL to be opened.
    @param reply The destination for any status. Won't use if it's typeNULL.
    @details Calls the initializer, creates a browser window for the URL, sets up connections between the instance and browser, and adds the instance to [NSOperationQueue mainQueue], which processes the reply event.
 
    Call from the Apple event handler that event and reply came from.
    @return The instance doing the actions, or nil if initialization failed.
 */
+ (instancetype)handleEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply {
    PrGetURLOperation * const  actor = [[self alloc] initWithEvent:event replyEvent:reply];
    
    if (actor) {
        [actor setupBrowser];
        [[NSOperationQueue mainQueue] addOperation:actor];
    }
    return actor;
}

/*!
    @brief Designated initializer.
    @param event The URL to be opened.
    @param reply The destination for any status.
    @details Extracts the parameters and suspends the event pair. Does not initiate the opening procedure.
 
    @return The generated instance, or nil if something failed. (The suspension of the Apple event happens after any code that can fail.)
 */
- (instancetype)initWithEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)reply {
    if (self = [super init]) {
        _status = loadUnstarted;
        if (!(_url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]])) {
            return nil;
        }
        if (!(_browser = [[NSApp delegate] createBrowser])) {
            return nil;
        }
        if (!(_eventPair = [[NSAppleEventManager sharedAppleEventManager] suspendCurrentAppleEvent])) {
            return nil;
        }
        _problem = nil;
    }
    return self;
}

#pragma mark KVO management

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *  keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    
    if ([key isEqualToString:NSStringFromSelector(@selector(isReady))]) {
        keyPaths = [keyPaths setByAddingObject:@"status"];
    }
    return keyPaths;
}

#pragma mark Browser creation and connection

/*!
    @brief Establishes browser notifications, shows the window, and starts to load the URL.
 */
- (void)setupBrowser {
    [self connectNotificationsForBrowser];
    [self.browser showWindow:NSApp];
    [self.browser loadPage:self.url];
}

/*!
    @brief Add the notifications from the browser window to this operation.
 */
- (void)connectNotificationsForBrowser {
    NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];
    
    [notifier addObserver:self selector:@selector(notifyOnCompletion:) name:NSWindowWillCloseNotification object:self.browser.window];
    [notifier addObserver:self selector:@selector(notifyOnCompletion:) name:PrBrowserLoadFailedNotification object:self.browser];
    [notifier addObserver:self selector:@selector(notifyOnCompletion:) name:PrBrowserLoadPassedNotification object:self.browser];
}

/*!
    @brief Response to any of the targeted notifications.
    @param notification The sent notification.
    @details Does common clean up and considers the processing of the URL to be finished.
 */
- (void)notifyOnCompletion:(NSNotification *)notification {
    if ([notification.name isEqualToString:NSWindowWillCloseNotification]) {
        self.status = loadCancelled;
    } else if ([notification.name isEqualToString:PrBrowserLoadFailedNotification]) {
        self.status = loadFailed;
    } else if ([notification.name isEqualToString:PrBrowserLoadPassedNotification]) {
        self.status = loadSucceeded;
    } else {
        self.status = loadFailed;  // Shouldn't get here.
    }
    self.problem = notification.userInfo[PrBrowserErrorKey];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Conventional overrides

- (BOOL)isReady {
    return [super isReady] && (self.status != loadUnstarted);
}

- (void)main {
    NSAppleEventManager * const   manager = [NSAppleEventManager sharedAppleEventManager];
    NSAppleEventDescriptor * const  reply = [manager replyAppleEventForSuspensionID:self.eventPair];

    if (reply.descriptorType != typeNull) {
        if (self.problem) {
            NSDictionary * const  userInfo = self.problem.userInfo;

            if ([self.problem.domain isEqualToString:NSOSStatusErrorDomain]) {
                [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:(SInt32)self.problem.code] forKeyword:keyErrorNumber];
            }
            if (userInfo) {
                id  value = nil;

                if ((value = userInfo[NSLocalizedFailureReasonErrorKey])) {
                    [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:value] forKeyword:keyErrorString];
                } else if ((value = userInfo[NSLocalizedDescriptionKey])) {
                    [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:value] forKeyword:keyErrorString];
                }
            } else {
                [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:self.problem.domain] forKeyword:keyErrorString];
            }
        } else if (self.isCancelled || (self.status == loadCancelled)) {
            [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:userCanceledErr] forKeyword:keyErrorNumber];
        } else if (self.status == loadFailed) {
            [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:fnfErr] forKeyword:keyErrorNumber];
        }
    }
    [manager resumeWithSuspensionID:self.eventPair];
}

@end
