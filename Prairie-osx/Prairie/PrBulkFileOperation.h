/*!
    @header
    @brief Declaration of a multi-file opening operation class.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;

@interface PrBulkFileOperation : NSOperation

+(instancetype)openFiles:(NSArray *)paths application:(NSApplication *)app;

@property (readonly) NSArray *        files;  // Elements are NSURL*
@property (readonly) NSApplication *  application;

@property (readonly) NSUInteger  handledCount;  // KVO-compliant

@end
