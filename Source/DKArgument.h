/** Interface for DKArgument class for boxing and unboxing D-Bus types.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

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

   <title>DKArgument class reference</title>
   */

#import<Foundation/NSObject.h>

#include <dbus/dbus.h>

@class NSString, NSMutableArray;

extern NSString *DKArgumentDirectionIn;
extern NSString *DKArgumentDirectionOut;


/**
 *  DKArgument encapsulates D-Bus argument information
 */
@interface DKArgument: NSObject
{
  DBusSignatureIter iterator;
  int DBusType;
  NSString *name;
  Class objCEquivalent;
  id parent;
}

- (id)initWithDBusSignature: (const char*)characters
                       name: (NSString*)name
                     parent: (id)parent;

- (BOOL)isContainerType;

- (char*)unboxedObjCTypeChar;
@end

/**
 * Encapsulates arguments that have sub-types and may require more complex
 * strategies to box and unbox.
 */
@interface DKContainerTypeArgument: DKArgument
{
  NSMutableArray *children;
}
@end;
