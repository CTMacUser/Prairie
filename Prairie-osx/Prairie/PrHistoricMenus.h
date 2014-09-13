/*!
    @header
    @brief Declaration of a web-history=to=menu management class.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

@import Foundation;
@import WebKit;


// Important property key-path strings.
//! Key-path string for the 'dayMenuItems' property.
extern NSString * const  PrKeyPathDayMenuItems;
//! Key-path string for the 'needsSaving' property.
extern NSString * const  PrKeyPathNeedsSaving;


@interface PrHistoricMenus : NSObject

/*!
    @brief Designated initializer
    @param history The source to build a menu group for, including watching for changes. Must not be nil; must be empty.
    @details Retains a reference to the history container and watches all of the container's notifications to update its internal data, including the generated menus.
    @return The new instance, or nil if an error occurred.
 */
- (instancetype)initWithHistory:(WebHistory *)history;

//! The web-history passed during initialization.
@property (nonatomic, readonly) WebHistory *  history;
//! The menu items for each day in history. Elements are NSMenuItem*, each with a submenu with items for each WebHistoryItem. KVO-compliant.
@property (nonatomic, readonly) NSArray *     dayMenuItems;
//! Starts as NO; sets to YES on any history/menu change, sets back to NO on load and save. KVO-compliant.
@property (nonatomic, readonly, assign) BOOL  needsSaving;
//! Starts as nil; sets after every save. KVO-compliant.
@property (nonatomic, readonly) NSDate *      lastSaved;

//! Starts with full date string and no time string; controls how day values are turned into menu (item) titles. You shouldn't reactivate time-string writes.
@property (nonatomic) NSDateFormatter *  dayFormatter;

@end
