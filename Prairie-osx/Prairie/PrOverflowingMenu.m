/*!
    @file
    @brief Definition of a menu-splitting management class.
    @details Copies a menu's items across two arrays, with a user-controlled split.

    @copyright Daryle Walker, 2014, all rights reserved.
    @CFBundleIdentifier io.github.ctmacuser.Prairie
 */

#import "PrOverflowingMenu.h"


#pragma mark Declared constants

NSString * const  PrKeyPathSourceMenu = @"sourceMenu";  // from this class
NSString * const  PrKeyPathMaxDirectCount = @"maxDirectCount";  // from this class
NSString * const  PrKeyPathDirectMenuItems = @"directMenuItems";  // from this class
NSString * const  PrKeyPathOverflowMenuItems = @"overflowMenuItems";  // from this class

#pragma mark - Private interface

@interface PrOverflowingMenu () {
    NSMutableArray *  _directMenuItems;
    NSMutableArray *  _overflowMenuItems;
}

/*!
    @brief Balences distribution of menu items.
    @details If there at most 'self.maxDirectCount' contained menu items, puts them all into the direct-item array. Otherwise, any excess goes into the overflow-item array. The direct items are before the overflow ones in the abstract.
 */
- (void)reconcileArrays;

/*!
    @brief Response to NSMenuDidAddItemNotification.
    @param note The sent notification.
    @details Adds a copy of the source menu's new item to the same relative place among the item arrays.
 */
- (void)notifyOnMenuItemAddition:(NSNotification *)note;
/*!
    @brief Response to NSMenuDidChangeItemNotification.
    @param note The sent notification.
    @details Updates the title of the menu item copied from the same relative spot of the source menu. (Currently does not update any other attribute.)
 */
- (void)notifyOnMenuItemChange:(NSNotification *)note;
/*!
    @brief Response to NSMenuDidRemoveItemNotification.
    @param note The sent notification.
    @details Removes the copy of the source menu's killed item from the appropriate item array.
 */
- (void)notifyOnMenuItemRemoval:(NSNotification *)note;

@end

#pragma mark -

@implementation PrOverflowingMenu

#pragma mark Initialization

- (instancetype)init {
    if (self = [super init]) {
        _directMenuItems = [[NSMutableArray alloc] init];
        _overflowMenuItems = [[NSMutableArray alloc] init];
        if (!_directMenuItems || !_overflowMenuItems) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Properties

- (void)setSourceMenu:(NSMenu *)sourceMenu {
    NSMutableArray * const  newDirectMenuItems = [[NSMutableArray alloc] init];
    NSMutableArray * const  newOverflowMenuItems = [[NSMutableArray alloc] init];
    NSInteger const         sourceLength = sourceMenu.numberOfItems;

    NSParameterAssert(newDirectMenuItems);
    NSParameterAssert(newOverflowMenuItems);
    for (NSInteger idx = 0; idx < sourceLength; ++idx) {
        [newOverflowMenuItems addObject:[[sourceMenu itemAtIndex:idx] copy]];
    }

    if (self->_sourceMenu) {
        // Detach old menu's connections.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:self->_sourceMenu];
    }
    self->_sourceMenu = sourceMenu;
    [self willChangeValueForKey:PrKeyPathDirectMenuItems];
    [self willChangeValueForKey:PrKeyPathOverflowMenuItems];
    self->_directMenuItems = newDirectMenuItems;
    self->_overflowMenuItems = newOverflowMenuItems;
    [self didChangeValueForKey:PrKeyPathOverflowMenuItems];
    [self didChangeValueForKey:PrKeyPathDirectMenuItems];
    if (self->_sourceMenu) {
        // Attach new menu's connections.
        NSNotificationCenter * const  notifier = [NSNotificationCenter defaultCenter];

        [notifier addObserver:self selector:@selector(notifyOnMenuItemAddition:) name:NSMenuDidAddItemNotification object:self->_sourceMenu];
        [notifier addObserver:self selector:@selector(notifyOnMenuItemChange:) name:NSMenuDidChangeItemNotification object:self->_sourceMenu];
        [notifier addObserver:self selector:@selector(notifyOnMenuItemRemoval:) name:NSMenuDidRemoveItemNotification object:self->_sourceMenu];
    }
    [self reconcileArrays];
}

- (void)setMaxDirectCount:(NSUInteger)maxDirectCount {
    self->_maxDirectCount = maxDirectCount;
    [self reconcileArrays];
}

@synthesize directMenuItems = _directMenuItems;

@synthesize overflowMenuItems = _overflowMenuItems;

#pragma mark Invariant maintainence

- (void)reconcileArrays {
    NSUInteger const  directCount = self->_directMenuItems.count;
    NSUInteger const  overflowCount = self->_overflowMenuItems.count;

    if (directCount > self->_maxDirectCount) {
        // Transfer excess trailing elements to be the leading elements of the overflow array.
        NSUInteger const   itemsToTransfer = directCount - self->_maxDirectCount;
        NSIndexSet * const  removedIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self->_maxDirectCount, itemsToTransfer)];
        NSIndexSet * const    addedIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0u, itemsToTransfer)];

        NSParameterAssert(removedIndexes);
        NSParameterAssert(addedIndexes);
        NSArray * const  transferredItems = [self->_directMenuItems objectsAtIndexes:removedIndexes];

        NSParameterAssert(transferredItems);
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndexes forKey:PrKeyPathDirectMenuItems];
        [self->_directMenuItems removeObjectsAtIndexes:removedIndexes];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndexes forKey:PrKeyPathDirectMenuItems];
        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndexes forKey:PrKeyPathOverflowMenuItems];
        [self->_overflowMenuItems insertObjects:transferredItems atIndexes:addedIndexes];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndexes forKey:PrKeyPathOverflowMenuItems];
    } else if ((directCount < self->_maxDirectCount) && overflowCount) {
        // Transfer leading elements of the overflow array to be the trailing elements.
        NSUInteger const    itemsToTransfer = MIN(overflowCount, self->_maxDirectCount - directCount);
        NSIndexSet * const  addedIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(directCount, itemsToTransfer)];
        NSIndexSet * const  removedIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0u, itemsToTransfer)];

        NSParameterAssert(addedIndexes);
        NSParameterAssert(removedIndexes);
        NSArray * const  transferredItems = [self->_overflowMenuItems objectsAtIndexes:removedIndexes];

        NSParameterAssert(transferredItems);
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndexes forKey:PrKeyPathOverflowMenuItems];
        [self->_overflowMenuItems removeObjectsAtIndexes:removedIndexes];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndexes forKey:PrKeyPathOverflowMenuItems];
        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndexes forKey:PrKeyPathDirectMenuItems];
        [self->_directMenuItems insertObjects:transferredItems atIndexes:addedIndexes];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndexes forKey:PrKeyPathDirectMenuItems];
    }
}

#pragma mark Notifications

- (void)notifyOnMenuItemAddition:(NSNotification *)note {
    NSInteger const  index = [note.userInfo[@"NSMenuItemIndex"] integerValue];
    NSArray * const  newMenuItemArray = @[[[self.sourceMenu itemAtIndex:index] copy]];

    NSParameterAssert(newMenuItemArray);
    if ((NSUInteger)index < self.directMenuItems.count) {
        // Add menu item to the direct item array.
        NSIndexSet * const  addedIndex = [NSIndexSet indexSetWithIndex:(NSUInteger)index];

        NSParameterAssert(addedIndex);
        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndex forKey:PrKeyPathDirectMenuItems];
        [self->_directMenuItems insertObjects:newMenuItemArray atIndexes:addedIndex];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndex forKey:PrKeyPathDirectMenuItems];
    } else {
        // Add menu item to the overflow item array.
        NSIndexSet * const  addedIndex = [NSIndexSet indexSetWithIndex:((NSUInteger)index - self.directMenuItems.count)];
        
        NSParameterAssert(addedIndex);
        [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndex forKey:PrKeyPathOverflowMenuItems];
        [self->_overflowMenuItems insertObjects:newMenuItemArray atIndexes:addedIndex];
        [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:addedIndex forKey:PrKeyPathOverflowMenuItems];
    }
    [self reconcileArrays];
}

- (void)notifyOnMenuItemChange:(NSNotification *)note {
    NSInteger const   index = [note.userInfo[@"NSMenuItemIndex"] integerValue];
    NSArray * const   array = (index < self.directMenuItems.count) ? self.directMenuItems : self.overflowMenuItems;
    NSUInteger const  localIndex = (NSUInteger)index - (array == self.directMenuItems ? 0u : self.directMenuItems.count);

    // There are many menu item attributes that can be changed, but the problem domain only needs to look at the title.
    [array[localIndex] setTitle:[self.sourceMenu itemAtIndex:index].title];
}

- (void)notifyOnMenuItemRemoval:(NSNotification *)note {
    NSUInteger const           index = (NSUInteger)[note.userInfo[@"NSMenuItemIndex"] integerValue];
    NSIndexSet * const  removedIndex = [NSIndexSet indexSetWithIndex:(index - ((index < self.directMenuItems.count) ? 0u : self.directMenuItems.count))];

    NSParameterAssert(removedIndex);
    if (index < self.directMenuItems.count) {
        // Remove menu item from the direct item array.
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndex forKey:PrKeyPathDirectMenuItems];
        [self->_directMenuItems removeObjectsAtIndexes:removedIndex];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndex forKey:PrKeyPathDirectMenuItems];
    } else {
        // Remove menu item from the overflow item array.
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndex forKey:PrKeyPathOverflowMenuItems];
        [self->_overflowMenuItems removeObjectsAtIndexes:removedIndex];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:removedIndex forKey:PrKeyPathOverflowMenuItems];
    }
    [self reconcileArrays];
}

@end
