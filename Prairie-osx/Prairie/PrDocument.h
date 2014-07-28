//
//  PrDocument.h
//  Prairie
//
//  Created by Daryle Walker on 7/25/14.
//  Copyright (c) 2014 Daryle Walker. All rights reserved.
//

@import Cocoa;
@import WebKit;

@interface PrDocument : NSDocument

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSTextField *urlDisplay;

@end
