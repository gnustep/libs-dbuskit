/** Protocol for the bus-facing protion of Canonical's DBus app menu.
   Copyright (C) 2013 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2013

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>DKDBusMenu protocol reference</title>
   */

#import <Foundation/NSObject.h>

@class NSArray, NSNumber, NSString;

@protocol DKDBusMenu <NSObject>

// FIXME: In the future, this will be properties:

/**
 * Returns the version of the DBusMenu API in use.
 */
- (uint32_t)Version;

/**
 * Returns the status of the menu. Either "normal" or "notice", depending on whether the menu needs attention.
 */
- (NSString*)Status;

/**
 * Returns an array with two elements: The first is the menu revision, and the second is an array that contains
 * a byzantine structure describing the menu items with the requested properties. See com.canonical.dbusmenu.xml
 * for a description.
 */
- (NSArray*)layoutForParent: (int32_t)parentID depth: (int32_t)depth properties: (NSArray*)propertyNames;

/**
 * Returns an array containing an array with two elements: The menu item ID, and a dictionary of the properties.
 */
- (NSArray*) menuItems: (NSArray*)menuItemIDs properties: (NSArray*)propertyNames;

/**
 * Returns the value of the property on the identified menu item.
 */
- (id)menuItem: (NSNumber*)menuID property: (NSString*)property;

/**
 * Called by the menu server when the menu item has been activated
 */
- (void)menuItem: (NSNumber*)menuID receivedEvent: (NSString*)eventType data: (id)data timestamp: (NSNumber*)timestamp;

/**
 * Called by the menu server when the menu item is about to be displayed
 */
- (BOOL)willShowMenuItem: (NSNumber*)menuID;

@end
