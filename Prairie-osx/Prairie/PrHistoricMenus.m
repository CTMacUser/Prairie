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

#pragma mark - Private NSValueTransformer

@interface PrObjectIdentityTransformer : NSValueTransformer

//! Starts as nil; the instance to be compared.
@property (nonatomic) id  compared;

@end

@implementation PrObjectIdentityTransformer

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    return [NSNumber numberWithBool:(self.compared == value)];
}

@end

#pragma mark - File-local functions

/*!
    @brief Makes a menu item representing a history day.
    @param day The date the menu item represents.
    @param format The object translating a day into a string value.
    @return A menu item titled with the day, with an empty submenu, and storing the day as extra data.
 */
static inline
NSMenuItem *  CreateMenuItemForDay(NSCalendarDate *day, NSDateFormatter *format) {
    NSString * const   dayTitle = [format stringFromDate:day];
    NSMenu * const   daySubmenu = [[NSMenu alloc] initWithTitle:dayTitle];
    NSMenuItem * const  dayItem = [[NSMenuItem alloc] initWithTitle:dayTitle action:NULL keyEquivalent:@""];

    dayItem.representedObject = day;
    dayItem.submenu = daySubmenu;

    // Attach a binding to let the menu item auto-hide when used as the Today menu item.
    PrairieAppDelegate * const           appDelegate = [NSApp delegate];
    PrObjectIdentityTransformer * const  transformer = [[PrObjectIdentityTransformer alloc] init];

    transformer.compared = dayItem.submenu;
    [dayItem bind:NSHiddenBinding toObject:appDelegate.todayHistoryHandler withKeyPath:PrKeyPathSourceMenu options:@{NSValueTransformerBindingOption: transformer}];
    return dayItem;
}

/*!
    @brief Makes a menu item representing a history entry.
    @param item The web-history entry the menu item represents.
    @return A menu item titled from the entry, linked to the revisit-history action, and storing the entry as extra data.
 */
static inline
NSMenuItem *  CreateMenuItemFromHistory(WebHistoryItem *item) {
    NSString *  itemTitle = item.title;

    if (nil == itemTitle) {  // Web-history entries have titles only if their resource properly has them.
        itemTitle = item.URLString;
    }
    NSMenuItem * const  historyMenuItem = [[NSMenuItem alloc] initWithTitle:itemTitle action:@selector(revisitHistory:) keyEquivalent:@""];

    historyMenuItem.representedObject = item;
    return historyMenuItem;
}

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
    NSArray * const              historyDays = self.history.orderedLastVisitedDays;
    NSMutableArray * const       newDayMenuItems = [[NSMutableArray alloc] initWithCapacity:historyDays.count];
    NSMutableDictionary * const  newMapDayToMenuItem = [[NSMutableDictionary alloc] initWithCapacity:historyDays.count];
    NSMutableDictionary * const  newMapHistoryItemToDay = [[NSMutableDictionary alloc] init];

    for (NSCalendarDate *day in historyDays) {
        NSMenuItem * const  dayMenuItem = CreateMenuItemForDay(day, self.dayFormatter);

        for (WebHistoryItem *item in [self.history orderedItemsLastVisitedOnDay:day]) {
            [dayMenuItem.submenu addItem:CreateMenuItemFromHistory(item)];
            newMapHistoryItemToDay[[NSValue valueWithNonretainedObject:item]] = day;
        }
        [newDayMenuItems addObject:dayMenuItem];
        newMapDayToMenuItem[day] = dayMenuItem;
    }
    [self willChangeValueForKey:PrKeyPathDayMenuItems];
    self->_dayMenuItems = newDayMenuItems;
    self.mapDayToMenuItem = newMapDayToMenuItem;
    self.mapHistoryItemToDay = newMapHistoryItemToDay;
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
    // Find what days are being added or removed (or staying around).
    NSOrderedSet * const         newHistoryDays = [NSOrderedSet orderedSetWithArray:self.history.orderedLastVisitedDays];
    NSMutableOrderedSet * const  oldHistoryDays = [[NSMutableOrderedSet alloc] initWithCapacity:self.dayMenuItems.count];

    for (NSMenuItem *item in self.dayMenuItems) {
        [oldHistoryDays addObject:item.representedObject];
    }
    NSMutableOrderedSet * const    addedHistoryDays = [newHistoryDays mutableCopy];
    NSMutableOrderedSet * const  removedHistoryDays = [oldHistoryDays mutableCopy];
    NSMutableOrderedSet * const   commonHistoryDays = [newHistoryDays mutableCopy];

    [addedHistoryDays minusOrderedSet:oldHistoryDays];
    [removedHistoryDays minusOrderedSet:newHistoryDays];
    [commonHistoryDays intersectOrderedSet:oldHistoryDays];

    // Prime menus for new days.
    for (NSCalendarDate *day in addedHistoryDays) {
        self.mapDayToMenuItem[day] = CreateMenuItemForDay(day, self.dayFormatter);
    }

    // Load all the new history items to the front of the latest old day.
    NSCalendarDate *  latestDay = commonHistoryDays.firstObject;

    if (!latestDay) latestDay = removedHistoryDays.firstObject;
    if (!latestDay) latestDay = addedHistoryDays.lastObject;
    NSMenu * const  latestDayMenu = [self.mapDayToMenuItem[latestDay] submenu];

    for (WebHistoryItem *item in [note.userInfo[WebHistoryItemsKey] reverseObjectEnumerator]) {
        NSMenuItem *  historyMenuItem;
        NSValue * const          itemValue = [NSValue valueWithNonretainedObject:item];
        NSCalendarDate * const   itemDay = self.mapHistoryItemToDay[itemValue];

        if (itemDay) {
            NSMenu * const  daySubmenu = [self.mapDayToMenuItem[itemDay] submenu];

            historyMenuItem = [daySubmenu itemAtIndex:[daySubmenu indexOfItemWithRepresentedObject:item]];
            [daySubmenu removeItem:historyMenuItem];
        } else {
            historyMenuItem = CreateMenuItemFromHistory(item);
        }
        [latestDayMenu insertItem:historyMenuItem atIndex:0];
        self.mapHistoryItemToDay[itemValue] = latestDay;
    }

    // Set any new days with their history menu items.
    for (NSCalendarDate *day in addedHistoryDays) {
        NSMenu * const  daySubmenu = [self.mapDayToMenuItem[day] submenu];

        for (WebHistoryItem *item in [self.history orderedItemsLastVisitedOnDay:day].reverseObjectEnumerator) {
            NSValue * const       itemValue = [NSValue valueWithNonretainedObject:item];
            NSCalendarDate * const  itemDay = self.mapHistoryItemToDay[itemValue];

            if ((nil == itemDay) || [itemDay isEqualToDate:day]) continue;  // Don't recurse nor bother with missed items.
            NSMenu * const       itemDaySubmenu = [self.mapDayToMenuItem[itemDay] submenu];
            NSMenuItem * const  historyMenuItem = [itemDaySubmenu itemAtIndex:[itemDaySubmenu indexOfItemWithRepresentedObject:item]];

            [itemDaySubmenu removeItem:historyMenuItem];
            [daySubmenu insertItem:historyMenuItem atIndex:0];
            self.mapHistoryItemToDay[itemValue] = day;
        }
    }

    // Publish any changes with added or removed days (changed days don't count).
    if (removedHistoryDays.count) {
        NSIndexSet * const  removedIndexes = [self.dayMenuItems indexesOfObjectsPassingTest:^BOOL(NSMenuItem *obj, NSUInteger idx, BOOL *stop) {
            return [removedHistoryDays containsObject:obj.representedObject];
        }];

        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndexes forKey:PrKeyPathDayMenuItems];
        for (NSCalendarDate *day in removedHistoryDays) {
            [self.mapHistoryItemToDay removeObjectsForKeys:[self.mapHistoryItemToDay allKeysForObject:day]];
            [self.mapDayToMenuItem removeObjectForKey:day];
        }
        [self->_dayMenuItems removeObjectsAtIndexes:removedIndexes];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndexes forKey:PrKeyPathDayMenuItems];
    }

    if (addedHistoryDays.count) {
        NSMutableArray * const  addedMenuItems = [[NSMutableArray alloc] initWithCapacity:addedHistoryDays.count];
        NSIndexSet * const      addedIndexes = [newHistoryDays indexesOfObjectsPassingTest:^BOOL(NSCalendarDate *obj, NSUInteger idx, BOOL *stop) {
            BOOL const  isAdded = [addedHistoryDays containsObject:obj];

            if (isAdded) {
                [addedMenuItems addObject:self.mapDayToMenuItem[obj]];
            }
            return isAdded;
        }];

        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndexes forKey:PrKeyPathDayMenuItems];
        [self->_dayMenuItems insertObjects:addedMenuItems atIndexes:addedIndexes];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndexes forKey:PrKeyPathDayMenuItems];
    }

    self.needsSaving = YES;
}

// See private interface for details.
- (void)notifyOnHistoryRemoveItems:(NSNotification *)note {
    // Purge the items.
    for (WebHistoryItem *item in note.userInfo[WebHistoryItemsKey]) {
        NSValue * const   itemValue = [NSValue valueWithNonretainedObject:item];
        NSCalendarDate * const  day = self.mapHistoryItemToDay[itemValue];

        if (day) {
            NSMenu * const   daySubmenu = [self.mapDayToMenuItem[day] submenu];
            NSInteger const  historyMenuItemIndex = [daySubmenu indexOfItemWithRepresentedObject:item];

            if (historyMenuItemIndex != -1) {
                [daySubmenu removeItemAtIndex:historyMenuItemIndex];
            }
            [self.mapHistoryItemToDay removeObjectForKey:itemValue];
        }
    }

    // Purge empty days
    NSIndexSet * const  emptyDays = [self.dayMenuItems indexesOfObjectsPassingTest:^BOOL(NSMenuItem *obj, NSUInteger idx, BOOL *stop) {
        return !obj.submenu.numberOfItems;
    }];

    if (!emptyDays) return;
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:emptyDays forKey:PrKeyPathDayMenuItems];
    [self->_dayMenuItems removeObjectsAtIndexes:emptyDays];
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:emptyDays forKey:PrKeyPathDayMenuItems];

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

        if (nil == desiredTitle) {
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
