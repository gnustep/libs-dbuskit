/** Proxy class for exporting an NSMenu via Canonical's D-Bus interface.
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

   <title>DKMenuProxy reference</title>
   */

#import <Foundation/NSObject.h>
#import <AppKit/NSMenu.h>
#import "DKDBusMenu.h"

@class DKNotificationCenter, NSRecursiveLock, NSMapTable;

@interface DKMenuProxy : NSObject <DKDBusMenu>
{
  NSMenu *representedMenu;
  NSUInteger revision;
  NSMapTable *nativeToDBus;
  NSMapTable *dBusToNative;
  NSRecursiveLock *lock;
  DKNotificationCenter *center;
  BOOL exported;
}
- (id)initWithMenu: (NSMenu*)menu;
- (void)menuUpdated: (NSMenu*)menu;
- (NSUInteger)DBusIDForMenuObject: (NSMenuItem*)item;
- (BOOL)isExported;
- (void)setExported: (BOOL)yesno;
@end
