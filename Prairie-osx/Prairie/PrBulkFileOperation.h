/*!
    @header
    @brief Declaration of a multi-file opening operation class.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;

@interface PrBulkFileOperation : NSOperation

+(instancetype)openFiles:(NSArray *)paths application:(NSApplication *)app searchingFor:(NSString *)search;
+(instancetype)printFiles:(NSArray *)paths application:(NSApplication *)app settings:(NSDictionary *)info panel:(BOOL)showPrintPanel;

@property (readonly) NSArray *        files;  // Elements are NSURL*
@property (readonly) NSApplication *  application;
@property (readonly) NSString *       search;  // May be nil
@property (readonly) NSPrintInfo *    printSettings;  // May be nil
@property (readonly, assign) BOOL     displayPrintPanel;  // Ignored if printSettings is nil

@property (readonly) NSUInteger  handledCount;  // KVO-compliant

@end
