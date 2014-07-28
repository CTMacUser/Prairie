/*!
 @file
 @brief Definition of the app's Document class, directly connected to its XIB.
 @details The document encloses a web browser experience.
 @copyright Daryle Walker, 2014, all rights reserved.
 @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrDocument.h"

#pragma mark Private members

@interface PrDocument ()

@property (nonatomic, copy) NSURL *    initialURL;
@property (nonatomic, copy) NSData *   initialData;
@property (nonatomic, copy) NSString * initialType;  // MIME type, not UTI

@end

@implementation PrDocument

#pragma mark Private data

@synthesize initialURL;
@synthesize initialData;
@synthesize initialType;

#pragma mark Conventional overrides

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
    return NSStringFromClass([self class]);
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    // Load the first page.
    if ( self.initialURL && self.initialData ) {
        // Opening a file, with pre-loaded information (from the "readFrom..." methods).
        [[self.webView mainFrame] loadData:self.initialData MIMEType:self.initialType textEncodingName:nil baseURL:self.initialURL];  // Can/should the initial* properties be cleared after this point?
    } else {
        // Open home page. (TODO: have this be a preference; support blank page.)
        [[self.webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.apple.com"]]];
    }
}

+ (BOOL)autosavesInPlace
{
    return NO;  // viewer-only app
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    WebDataSource * const  source = self.webView.mainFrame.dataSource;
    NSData * const         data = [typeName isEqualToString:(__bridge NSString *)kUTTypeWebArchive] ? source.webArchive.data : source.data;  // Assumes typeName is the actual UTI for current web object when the object isn't a web-archive.

    if ( !data && outError ) {
        *outError = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];  // Is the error code appropriate?
    }
    return data;
    // TODO: currently doesn't work right. Regular saves (and save-as) and reverts seem to be bad ideas. Export seems to work when web-archive is the format, but not public-content. The latter has no extension/type-information to pass on, so the exported file is untyped and useless. Is my assumption on the line for local variable "data" wrong? Should the app switch from Editor to Viewer? (That will require making a subclass of NSDocumentController to open windows correctly.)
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    self.initialData = data;
    return YES;  // misnomer: data isn't actually read until the XIB's WebView loads it; can't get errors either
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    // The default implementation calls the NSFileWrapper version, which calls the NSData version.  The WebView takes in an NSData and NSURL, so we need two overrides to get all the information.  The URL data will always be grabbed as long as calling code only uses the URL version and never skips ahead to directly call the NSData version.
    CFStringRef const  mimeType = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) typeName, kUTTagClassMIMEType);

    self.initialType = mimeType ? (__bridge NSString *)mimeType : @"application/octet-stream";
    if ( [WebView canShowMIMEType:self.initialType] ) {
        self.initialURL = url;
        return [super readFromURL:url ofType:typeName error:outError];
    }
    if ( outError ) {
        *outError = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{NSURLErrorKey: url}];  // Is the error code appropriate?
    }
    return NO;  // Cannot proceed if WebView can't process the required MIME type.
}

- (BOOL)isEntireFileLoaded
{
    // The file is loaded when the WebView finishes with it.
    return self.webView && !self.webView.isLoading;
}

@end
