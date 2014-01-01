/** Interface for collection classes that are boxed as D-Bus structures
   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2014

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
   */

#import <Foundation/NSArray.h>

/**
 * The DKStruct protocol should be adopted by all collection classes
 * that are required to be converted to D-Bus structures. A default
 * implementation is provided for NSArray, which just returns NO.
 * The object also needs to implement -objectEnumerator.
 */
@protocol DKStruct
/**
 * Return YES from this method if the D-Bus representation of the 
 * receiver should be a struct instead of an array.
 */
- (BOOL)isDBusStruct;
@end

@interface NSArray (DBusKit) <DKStruct>
@end

@interface DKStructArray : NSArray
{
  NSArray *backingStore;
}
@end

@interface DKMutableStructArray : NSMutableArray
{
  NSMutableArray *backingStore;
}
@end
