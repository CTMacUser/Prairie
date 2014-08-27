/*!
    @header
    @brief Declaration of a multi-file opening (and printing) management class.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


@interface PrFileOpener : NSObject

/*!
    @brief Designated initializer.
    @param paths The list of files to open (and possibly print). The elements are NSString objects, each representing the path to its target file.
    @param app The application object.
    @details Stores copies of the application object (by reference) and the file list. Sets up internal attributes.
    @return The instance, or nil if something failed.
 */
- (instancetype)initWithFiles:(NSArray *)paths application:(NSApplication *)app;

/*!
    @brief Trigger the opening (and possibly either searching or printing afterwards) procedure.
    @details This should be called after a delay in the run loop.
 */
- (void)start;

//! A copy of the files to process. Elements are NSURL*, instead of path strings. Files whose paths failed URL-conversion are absent and won't be opened.
@property (nonatomic, readonly) NSArray        *files;
//! A (strong) reference to the targeted application object.
@property (nonatomic, readonly) NSApplication  *application;

//! Starts as nil; but if set, the first (case-insensitive) occurrence of the string in each open file will be selected. Ignored when printing.
@property (nonatomic, copy)   NSString     *search;
//! Starts as nil; but if set, each file will be printed after opening.
@property (nonatomic)         NSPrintInfo  *settings;
//! Set to control whether or not the Print panel will be shown for each file when printing starts. Ignored when not printing. (Starts as NO.)
@property (nonatomic, assign) BOOL         showPrintPanel;

//! Starts as NO, but will change to YES after no files remain to be processed. Is KVO-compliant.
@property (nonatomic, readonly, assign) BOOL  finished;

@end
