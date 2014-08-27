/*!
    @file
    @brief Definition of a handler class for the Get-URL Apple event.
    @details An operation sets up and completes the handling of a Get-URL Apple event.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrGetURLHandler.h"
#import "PrBrowserController.h"
#import "PrairieAppDelegate.h"

@import AppKit;
@import CoreServices;


#pragma mark File-local types

typedef enum : NSUInteger {
    loadUnstarted,
    loadCancelled,
    loadSucceeded,
    loadFailed,
} PrLoadStatus;

#pragma mark Private interface

@interface PrGetURLHandler ()

/*!
    @brief Response to NSWindowWillCloseNotification.
    @param note The sent notification.
    @details Finishes the loaded as cancelled.
 */
- (void)notifyFromWindow:(NSNotification *)note;
/*!
    @brief Response to PrBrowserLoadFailedNotification.
    @param note The sent notification.
    @details Finishes the loaded as failed. Records the error, too.
 */
- (void)notifyOnLoadFail:(NSNotification *)note;
/*!
    @brief Response to PrBrowserLoadPassedNotification.
    @param note The sent notification.
    @details Finishes the loaded as successful.
 */
- (void)notifyOnLoadSuccess:(NSNotification *)note;

/*!
    @brief Completion routine.
    @details If the loading cycle has completed (successfully or not), write any errors to the reply event and set the completion flag.
 */
- (void)finish;

@property (nonatomic, assign) PrLoadStatus  status;
@property (nonatomic) PrBrowserController  *browser;
@property (nonatomic, copy) NSURL          *url;
@property (nonatomic) NSError              *error;

@property (nonatomic, readwrite, assign) BOOL  finished;  // Made writable here to trigger KVO.

@end

@implementation PrGetURLHandler

#pragma mark Initialization

// See the header for details.
- (instancetype)init {
    if (self = [super init]) {
        NSAppleEventManager * const  manager = [NSAppleEventManager sharedAppleEventManager];

        _status = loadUnstarted;
        if (!(_browser = [[NSApp delegate] createBrowser])) {
            return nil;
        }
        if (!(_url = [NSURL URLWithString:[[[manager currentAppleEvent] paramDescriptorForKeyword:keyDirectObject] stringValue]])) {
            return nil;
        }

        _finished = NO;
        if (!(_eventPair = [manager suspendCurrentAppleEvent])) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];  // In case instance is killed early.
}

#pragma mark Notifications

- (void)notifyFromWindow:(NSNotification *)note {
    self.status = loadCancelled;
    [self finish];
}

- (void)notifyOnLoadFail:(NSNotification *)note {
    self.status = loadFailed;
    self.error = note.userInfo[PrBrowserErrorKey];
    [self finish];
}

- (void)notifyOnLoadSuccess:(NSNotification *)note {
    self.status = loadSucceeded;
    [self finish];
}

#pragma mark Operations

// See the header for details.
- (void)start {
    NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];
    
    [notifier addObserver:self selector:@selector(notifyFromWindow:) name:NSWindowWillCloseNotification object:self.browser.window];
    [notifier addObserver:self selector:@selector(notifyOnLoadFail:) name:PrBrowserLoadFailedNotification object:self.browser];
    [notifier addObserver:self selector:@selector(notifyOnLoadSuccess:) name:PrBrowserLoadPassedNotification object:self.browser];
    [self.browser showWindow:NSApp];
    [self.browser loadPage:self.url];
}

- (void)finish {
    if (!self.finished && self.status != loadUnstarted) {
        NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];
        NSAppleEventManager * const    manager = [NSAppleEventManager sharedAppleEventManager];
        NSAppleEventDescriptor * const   reply = [manager replyAppleEventForSuspensionID:self.eventPair];
        
        if (reply.descriptorType != typeNull) {
            if (self.error) {
                NSDictionary * const  userInfo = self.error.userInfo;
                
                if ([self.error.domain isEqualToString:NSOSStatusErrorDomain]) {
                    [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:(SInt32)self.error.code] forKeyword:keyErrorNumber];
                }
                if (userInfo) {
                    id  value = nil;
                    
                    if ((value = userInfo[NSLocalizedFailureReasonErrorKey])) {
                        [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:value] forKeyword:keyErrorString];
                    } else if ((value = userInfo[NSLocalizedDescriptionKey])) {
                        [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:value] forKeyword:keyErrorString];
                    }
                } else {
                    [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:self.error.domain] forKeyword:keyErrorString];
                }
            } else if (self.status == loadCancelled) {
                [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:userCanceledErr] forKeyword:keyErrorNumber];
            } else if (self.status == loadFailed) {
                [reply setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:fnfErr] forKeyword:keyErrorNumber];
            }
            // There isn't any direct return. (Technically, the original docs want the error code as the direct return. But I think that's inapproriate. And I don't think OS X would bother paying attention to that spec.)
        }
        [manager resumeWithSuspensionID:self.eventPair];
        [notifier removeObserver:self name:nil object:self.browser];
        [notifier removeObserver:self name:NSWindowWillCloseNotification object:self.browser.window];
        self.finished = YES;
    }
}

@end
