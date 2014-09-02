/*!
    @file
    @brief Definition of a web-history=to=menu management class.
    @details Builds menu items and submenus correspoding to a web-history's containment hierarchy, and syncs updates.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrHistoricMenus.h"
#import "PrairieAppDelegate.h"


#pragma mark Declared constants

NSString * const  PrKeyPathDayMenuItems = @"dayMenuItems";  // from this class

#pragma mark Private interface

@interface PrHistoricMenus () {
    NSMutableArray *  _dayMenuItems;
}

/*!
    @brief Response to WebHistoryLoadedNotification.
    @param note The sent notification.
    @details Creates menu items for each web-history day, each with a submenu that has menu items for each web-history entry.
 */
- (void)notifyOnHistoryLoad:(NSNotification *)note;
/*!
    @brief Response to WebHistorySavedNotification.
    @param note The sent notification.
    @details Updates the last-saved date and flips the needs-saving flag to NO.
 */
- (void)notifyOnHistorySave:(NSNotification *)note;
/*!
    @brief Response to WebHistoryItemsAddedNotification.
    @param note The sent notification.
    @details Creates menu items for the specified web-history entries and inserts them into the appropriate web-history day submenu. If an entry is already in a web-history day submenu, it is transferred to its new position.
 */
- (void)notifyOnHistoryAddItems:(NSNotification *)note;
/*!
    @brief Response to WebHistoryItemsRemovedNotification.
    @param note The sent notification.
    @details Releases the menu items for the specified web-history entries from their containing web-history day submenu.
 */
- (void)notifyOnHistoryRemoveItems:(NSNotification *)note;
/*!
    @brief Response to WebHistoryAllItemsRemovedNotification.
    @param note The sent notification.
    @details Releases all web-history day menu items.
 */
- (void)notifyOnHistoryRemoveAllItems:(NSNotification *)note;
/*!
    @brief Response to WebHistoryItemChangedNotification.
    @param note The sent notification.
    @details If needed, updates the title of the menu item mapped to the notifying web-history item.
 */
- (void)notifyOnHistoryItemChanges:(NSNotification *)note;

// Redeclare read/write properties that are read-only for users.
@property (nonatomic, assign) BOOL  needsSaving;
@property (nonatomic) NSDate *      lastSaved;

//! NSCalendarDate -> NSMenuItem: For a given day, its menu item with a submenu of menu items for web-history entries. The NSMenuItem instances are ones directly stored in "dayMenuItems".
@property (nonatomic) NSMutableDictionary *  mapDayToMenuItem;
//! (WebHistoryItem -> NSValue) -> NSCalendarDate: For a given web-history entry, the day it was last visited. Since keys are copied, but WebHistoryItem is mutable, items have to be wrapped in NSValue instances to preseve by-reference semantics.
@property (nonatomic) NSMutableDictionary *  mapHistoryItemToDay;

@end

#pragma mark -

@implementation PrHistoricMenus

#pragma mark Initialization

- (instancetype)initWithHistory:(WebHistory *)history {
    if (self = [super init]) {
        NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

        _dayMenuItems = [[NSMutableArray alloc] init];
        _dayFormatter = [[NSDateFormatter alloc] init];
        _mapDayToMenuItem = [[NSMutableDictionary alloc] init];
        _mapHistoryItemToDay = [[NSMutableDictionary alloc] init];
        if (!history || history.orderedLastVisitedDays.count || !_dayMenuItems || !_dayFormatter || !_mapDayToMenuItem || !_mapHistoryItemToDay) {
            return nil;
        } else {
            _history = history;
        }

        [notifier addObserver:self selector:@selector(notifyOnHistoryLoad:) name:WebHistoryLoadedNotification object:history];
        [notifier addObserver:self selector:@selector(notifyOnHistorySave:) name:WebHistorySavedNotification object:history];
        [notifier addObserver:self selector:@selector(notifyOnHistoryAddItems:) name:WebHistoryItemsAddedNotification object:history];
        [notifier addObserver:self selector:@selector(notifyOnHistoryRemoveItems:) name:WebHistoryItemsRemovedNotification object:history];
        [notifier addObserver:self selector:@selector(notifyOnHistoryRemoveAllItems:) name:WebHistoryAllItemsRemovedNotification object:history];
        [notifier addObserver:self selector:@selector(notifyOnHistoryItemChanges:) name:WebHistoryItemChangedNotification object:nil];

        _dayFormatter.dateStyle = NSDateFormatterFullStyle;
        _dayFormatter.timeStyle = NSDateFormatterNoStyle;
        _needsSaving = NO;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Properties

@synthesize dayMenuItems = _dayMenuItems;

#pragma mark NSKeyValueObservingCustomization override

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:PrKeyPathDayMenuItems]) {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

#pragma mark Notifications

// See private interface for details.
- (void)notifyOnHistoryLoad:(NSNotification *)note {
    NSMutableArray * const       newDayMenuItems = [[NSMutableArray alloc] initWithCapacity:self.history.orderedLastVisitedDays.count];
    NSMutableDictionary * const  newMapDaysToMenuItems = [[NSMutableDictionary alloc] initWithCapacity:self.history.orderedLastVisitedDays.count];
    NSMutableDictionary * const  newHistoryItemToDay = [[NSMutableDictionary alloc] init];

    for (NSCalendarDate *day in self.history.orderedLastVisitedDays) {
        NSString * const    dayTitle = [self.dayFormatter stringFromDate:day];
        NSMenuItem * const  dayMenuItem = [[NSMenuItem alloc] initWithTitle:dayTitle action:NULL keyEquivalent:@""];
        NSMenu * const      daySubmenu = [[NSMenu alloc] initWithTitle:dayTitle];

        dayMenuItem.submenu = daySubmenu;
        dayMenuItem.representedObject = day;
        for (WebHistoryItem *item in [self.history orderedItemsLastVisitedOnDay:day]) {
            NSString *          itemTitle = item.title;
            NSMenuItem * const  historyMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(revisitHistory:) keyEquivalent:@""];

            if (nil == itemTitle) {  // Web-history entries have titles only if their resource properly has them.
                itemTitle = item.URLString;
            }
            historyMenuItem.title = itemTitle;
            historyMenuItem.representedObject = item;
            newHistoryItemToDay[[NSValue valueWithNonretainedObject:item]] = day;
            [daySubmenu addItem:historyMenuItem];
        }
        [newDayMenuItems addObject:dayMenuItem];
        newMapDaysToMenuItems[day] = dayMenuItem;
    }
    [self willChangeValueForKey:PrKeyPathDayMenuItems];
    _dayMenuItems = newDayMenuItems;
    self.mapDayToMenuItem = newMapDaysToMenuItems;
    self.mapHistoryItemToDay = newHistoryItemToDay;
    [self didChangeValueForKey:PrKeyPathDayMenuItems];

    self.needsSaving = NO;
}

// See private interface for details.
- (void)notifyOnHistorySave:(NSNotification *)note {
    self.needsSaving = NO;
    self.lastSaved = [NSDate date];
}

// See private interface for details.
- (void)notifyOnHistoryAddItems:(NSNotification *)note {
    // Quick & dirty: call the menu procedure that loads use to do a reset to the current history state.
    // TODO: implement this method properly
    [self notifyOnHistoryLoad:note];
    self.needsSaving = YES;
}

// See private interface for details.
- (void)notifyOnHistoryRemoveItems:(NSNotification *)note {
    // Quick & dirty: call the menu procedure that loads use to do a reset to the current history state.
    // TODO: implement this method properly
    [self notifyOnHistoryLoad:note];
    self.needsSaving = YES;
}

// See private interface for details.
- (void)notifyOnHistoryRemoveAllItems:(NSNotification *)note {
    if ([note.userInfo[WebHistoryItemsKey] count] > 0u) {  // Don't post changes if the container was already empty!
        [self willChangeValueForKey:PrKeyPathDayMenuItems];
        [self->_dayMenuItems removeAllObjects];
        [self.mapDayToMenuItem removeAllObjects];
        [self.mapHistoryItemToDay removeAllObjects];
        [self didChangeValueForKey:PrKeyPathDayMenuItems];
        self.needsSaving = YES;
    }
}

// See private interface for details.
- (void)notifyOnHistoryItemChanges:(NSNotification *)note {
    if (!self.dayMenuItems || !self.dayMenuItems.count) return;

    // Check if any history menu item titles would actually change.
    NSMenu * const               firstDaySubmenu = [self.dayMenuItems.firstObject submenu];
    NSInteger               historyMenuItemCount = firstDaySubmenu.numberOfItems;
    NSMutableIndexSet * const  menuItemsToChange = [[NSMutableIndexSet alloc] init];
    NSMutableArray * const      newHistoryTitles = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)historyMenuItemCount];

    if (!menuItemsToChange || !newHistoryTitles) return;
    for (NSInteger i = 0; i < historyMenuItemCount; ++i) {
        NSMenuItem * const  historyMenuItem = [firstDaySubmenu itemAtIndex:i];
        WebHistoryItem * const  historyItem = historyMenuItem.representedObject;
        NSString *             desiredTitle = historyItem.title;

        if (!desiredTitle) {
            desiredTitle = historyItem.URLString;
        }
        if (![historyMenuItem.title isEqualToString:desiredTitle]) {
            [menuItemsToChange addIndex:(NSUInteger)i];
            [newHistoryTitles addObject:desiredTitle];
        }
    }
    if (!menuItemsToChange.count) return;

    // Change the titles, which are nested attributes of the first element of 'dayMenuItems'.
    NSEnumerator * const  historyTitleEnumerator = [newHistoryTitles objectEnumerator];
    NSIndexSet * const       dayMenuItemToChange = [NSIndexSet indexSetWithIndex:0u];

    if (!historyTitleEnumerator || !dayMenuItemToChange) return;
    [menuItemsToChange enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [firstDaySubmenu itemAtIndex:(NSInteger)idx].title = [historyTitleEnumerator nextObject];
    }];  // There originally was a will/did-change message pair surrounding this message, but it didn't fit since there's no KVO change-type for mutating an element (not the same as replacing an element). Since the change is on current menu items, they'll be automatically updated.
}

@end
