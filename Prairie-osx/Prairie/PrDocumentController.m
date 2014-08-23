/*!
    @file
    @brief Definition of the app's document controller, connected to the main XIB.
    @details The document controller handles creating new documents, opening existing ones, and managing the "Open Recent" list.
 
    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrDocumentController.h"

@import CoreServices;


@implementation PrDocumentController

#pragma mark Conventional overrides

- (IBAction)newDocument:(id)sender {
    [[NSApp delegate] applicationOpenUntitledFile:NSApp];
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel * const  panel = [NSOpenPanel openPanel];

    panel.allowsMultipleSelection = YES;
    panel.delegate = [NSApp delegate];  // The app delegate doubles as an Open/Save filter.
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

@end
