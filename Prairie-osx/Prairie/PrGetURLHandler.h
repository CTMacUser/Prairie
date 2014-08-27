/*!
    @header
    @brief Declaration of a handler class for the Get-URL Apple event.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Foundation;


@interface PrGetURLHandler : NSObject

/*!
    @brief Designated initializer.
    @details The Apple event and reply pair to be handled must be current one. Suspends the event pair (making them no longer current) and extracts the URL parameter.
    @return The instance, or nil if something failed. (The event pair is suspended only after any may-fail parts pass.)
 */
- (instancetype)init;

/*!
    @brief Trigger the opening procedure, creating a browser window and loading the URL in it.
    @details This should be called after a delay in the run loop. If the reply event isn't Null, the results and/or errors will be copied to it before it (and its matching incoming event) are un-suspended.
 */
- (void)start;

//! The token representing the post-suspension Apple event and reply pair.
@property (nonatomic, readonly, assign) NSAppleEventManagerSuspensionID  eventPair;

//! Starts as NO, but will change to YES after the URL is processed. Is KVO-compliant.
@property (nonatomic, readonly, assign) BOOL  finished;

@end
