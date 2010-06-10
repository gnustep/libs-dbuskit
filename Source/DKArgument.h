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


@class NSString, NSMutableArray;

extern NSString *DKArgumentDirectionIn;
extern NSString *DKArgumentDirectionOut;


/**
 *  DKArgument encapsulates D-Bus argument information
 */
@interface DKArgument: NSObject
{
  int DBusType;
  NSString *name;
  Class objCEquivalent;
  id parent;
}

- (id) initWithDBusSignature: (const char*)characters
                        name: (NSString*)name
                      parent: (id)parent;

/**
 * Return whether the argument is a complex one that is made up by further
 * types.
 */
- (BOOL) isContainerType;

/**
 * Return the type char to be used if the argument is not boxed to an
 * Objective-C type.
 */
- (char*) unboxedObjCTypeChar;

/**
 * Return the size of the unboxed type.
 */
- (size_t) unboxedObjCTypeSize;

/**
 * Return the class that will represent an argument of this type.
 */
- (Class) objCEquivalent;

/**
 * Return the D-Bus type signature equivalent to the argument.
 */
- (NSString*) DBusTypeSignature;

/**
 * Returns a boxed representation of the value in buffer according to the type
 * of the DKArgument.
 */
- (id) boxedValueForValueAt: (void*)buffer;
@end

/**
 * Encapsulates arguments that have sub-types and may require more complex
 * strategies to box and unbox.
 */
@interface DKContainerTypeArgument: DKArgument
{
  NSMutableArray *children;
}

/**
 * Return all sub-arguments that make up this argument.
 */
- (NSArray*) children;
@end;
