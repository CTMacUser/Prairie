/*!
    @file
    @brief Definition of the app's document controller, connected to the main XIB.
    @details The document controller handles creating new documents, opening existing ones, and managing the "Open Recent" list.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrDocumentController.h"
#import "PrairieAppDelegate.h"
#import "PrWebViewShowMIMEValidator.h"

@import ApplicationServices;
@import CoreServices;


#pragma mark Private interface

@interface PrDocumentController ()

@property (nonatomic) PrWebViewShowMIMEValidator *  openPanelDelegate;  // Redeclarations must go from readonly to readwrite.

@end

@implementation PrDocumentController

#pragma mark Initialization

- (instancetype)init {
    if (self = [super init]) {
        _openPanelDelegate = [[PrWebViewShowMIMEValidator alloc] init];
    }
    return self;
}

#pragma mark Conventional overrides

- (IBAction)newDocument:(id)sender {
    (void)[(PrairieAppDelegate *)[NSApp delegate] applicationOpenUntitledFile:NSApp];
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel * const  panel = [NSOpenPanel openPanel];

    panel.allowsMultipleSelection = YES;
    panel.delegate = self.openPanelDelegate;
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSAppleEventDescriptor * const   fileList = [NSAppleEventDescriptor listDescriptor];
            NSAppleEventDescriptor * const  openEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenDocuments targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

            for (NSURL *file in panel.URLs) {
                [fileList insertDescriptor:[NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:[[file absoluteString] dataUsingEncoding:NSUTF8StringEncoding]] atIndex:0];
            }
            [openEvent setParamDescriptor:fileList forKeyword:keyDirectObject];
            [[NSAppleEventManager sharedAppleEventManager] dispatchRawAppleEvent:[openEvent aeDesc] withRawReply:(AppleEvent *)[[NSAppleEventDescriptor nullDescriptor] aeDesc] handlerRefCon:(SRefCon)0];
        }
    }];
}

#pragma mark NSUserInterfaceValidations override

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem {
    if ([anItem action] == @selector(newDocument:)) {
        return YES;
    } else if ([anItem action] == @selector(openDocument:)) {
        return YES;
    }
    return [super validateUserInterfaceItem:anItem];
}

#pragma mark Action methods

// See header for details.
- (IBAction)printMore:(id)sender {
    NSOpenPanel * const  panel = [NSOpenPanel openPanel];
    
    panel.allowsMultipleSelection = YES;
    panel.delegate = self.openPanelDelegate;
    panel.prompt = NSLocalizedString(@"PRINT_BUTTON", nil);
    panel.title = NSLocalizedString(@"PRINT_DIALOG_TITLE", nil);
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSAppleEventDescriptor * const    fileList = [NSAppleEventDescriptor listDescriptor];
            NSAppleEventDescriptor * const  printEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEPrintDocuments targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
            
            for (NSURL *file in panel.URLs) {
                [fileList insertDescriptor:[NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:[[file absoluteString] dataUsingEncoding:NSUTF8StringEncoding]] atIndex:0];
            }
            [printEvent setParamDescriptor:fileList forKeyword:keyDirectObject];
            [printEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithBoolean:YES] forKeyword:kPMShowPrintDialogAEType];
            [[NSAppleEventManager sharedAppleEventManager] dispatchRawAppleEvent:[printEvent aeDesc] withRawReply:(AppleEvent *)[[NSAppleEventDescriptor nullDescriptor] aeDesc] handlerRefCon:(SRefCon)0];
        }
    }];
}

@end
