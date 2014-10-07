/*!
    @file
    @brief Definition of the controller class for source-view windows.
    @details A source-view window shows the raw text of a page from a browser window.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrSourceViewController.h"
#import "PrairieAppDelegate.h"


#pragma mark File-local constants

// Keys for restorable properties.
//! Key-path string for the 'sourceText' property.
static NSString * const  PrKeyPathSourceText = @"sourceText";
//! Key-path string for the 'sourceURL' property.
static NSString * const  PrKeyPathSourceURL = @"sourceURL";
//! Key-path string for the 'urlAlternate' property.
static NSString * const  PrKeyPathURLAlternate = @"urlAlternate";
//! Key-path string for the 'sourceTitle' property.
static NSString * const  PrKeyPathSourceTitle = @"sourceTitle";

#pragma mark Private Interface

@interface PrSourceViewController () <NSWindowRestoration>

/*!
    @brief Creates a source-view window, with a matching controller of this type.
    @details Registers the window (controller) with the application delegate.
    @return The window controller of the new window, NIL if something went wrong.
 */
+ (instancetype)createSourceViewer;

/*!
    @brief The core name of this class, used for the XIB name and its window identifier.
    @return The name of this class, minus the "Controller" part.
 */
+ (NSString *)coreName;

// Attributes
//! The text source of the targeted web resource.
@property (nonatomic, copy) NSString *                     sourceText;
//! URL of the web resource, or what it's supposed to be if a web-error page is generated instead.
@property (nonatomic, copy) NSURL *                        sourceURL;
//! Whether or not the source-URL was actually loaded, or if a web-error page was generated instead.
@property (nonatomic, assign, getter=isUrlAlternate) BOOL  urlAlternate;
//! The title of the window, synthesized from the web resource's title or URL.
@property (nonatomic, copy) NSString *                     sourceTitle;

@end

@implementation PrSourceViewController

#pragma mark Factory methods

// See private interface for details.
+ (instancetype)createSourceViewer {
    PrSourceViewController * const  controller = [self new];
    NSWindow * const                    window = controller.window;  // Force creation of window.

    if (window) {
        [[NSApp delegate] registerWindow:window];
    }
    return controller;
}

// See header for details.
+ (instancetype)createViewerOfSource:(WebDataSource *)source {
    PrSourceViewController * const           controller = [self createSourceViewer];
    id<WebDocumentRepresentation> const  representation = source.representation;

    NSParameterAssert(!!source);
    if (controller) {
        if (representation && [representation canProvideDocumentSource]) {
            controller.sourceText = [representation documentSource];
        }
        controller.sourceURL = source.unreachableURL ?: source.response.URL ?: source.request.URL ?: source.initialRequest.URL;
        controller.urlAlternate = !!source.unreachableURL;
        controller.sourceTitle = [representation title] ?: [controller.sourceURL.lastPathComponent stringByRemovingPercentEncoding];
    }
    return controller;
}

#pragma mark Initialization

- (instancetype)init {
    if (self = [super initWithWindowNibName:[self.class coreName]]) {
        _sourceText = @"<html></html>";
        _sourceURL = [NSURL URLWithString:@"about:blank"];
        _sourceTitle = [NSString string];
        if (!_sourceText || !_sourceURL || !_sourceTitle) return nil;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Point to user-interface restoration class.
    self.window.restorationClass = self.class;

    // Get the right text settings.
    self.textView.font = [NSFont userFixedPitchFontOfSize:0.0];
}

#pragma mark NSWindowRestoration override

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
    if ([identifier isEqualToString:[self coreName]]) {
        completionHandler([[self createSourceViewer] window], nil);
    } else {
        completionHandler(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil]);
    }
}

#pragma mark NSRestorableState override

+ (NSArray *)restorableStateKeyPaths {
    return [[super restorableStateKeyPaths] arrayByAddingObjectsFromArray:@[PrKeyPathSourceText, PrKeyPathSourceURL, PrKeyPathURLAlternate, PrKeyPathSourceTitle]];
}

#pragma mark Private methods, administration

// See private interface for details.
+ (NSString *)coreName {
    return [NSStringFromClass(self) stringByReplacingOccurrencesOfString:@"Controller" withString:@""];
}

#pragma mark Actions

- (IBAction)printDocument:(id)sender {
    return [self.textView print:sender];
}

@end
