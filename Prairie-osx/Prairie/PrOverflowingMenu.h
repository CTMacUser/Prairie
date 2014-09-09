/*!
    @header
    @brief Declaration of a menu-splitting management class.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Cocoa;


// Property key-path strings.
//! Key-path string for the 'sourceMenu' property.
extern NSString * const  PrKeyPathSourceMenu;
//! Key-path string for the 'maxDirectCount' property.
extern NSString * const  PrKeyPathMaxDirectCount;
//! Key-path string for the 'directMenuItems' property.
extern NSString * const  PrKeyPathDirectMenuItems;
//! Key-path string for the 'overflowMenuItems' property.
extern NSString * const  PrKeyPathOverflowMenuItems;

@interface PrOverflowingMenu : NSObject

//! Starts as nil; when set, this instance stores copies of the menu's items and tracks the menu for item insertions, removals, and renames.
@property (nonatomic) NSMenu *            sourceMenu;
//! Starts as zero; if the menu has more menu items that this value, the copies of the menu's latter items are stored in the overflow array instead of the direct array.
@property (nonatomic, assign) NSUInteger  maxDirectCount;

//! Starts as empty; updated to mirror the source menu's menu-items. Keeps at most 'maxDirectCount' items. KVO-compliant.
@property (nonatomic, readonly) NSArray *    directMenuItems;
//! Starts as empty; updated to mirror the source menu's menu-items. Keeps the overflow from 'directMenuItems'. KVO-compliant.
@property (nonatomic, readonly) NSArray *  overflowMenuItems;

@end
