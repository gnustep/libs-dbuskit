/* -*-objc-*-
  Distributed objects bridge for D-Bus
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Ricardo Correa <r.correa.r@gmail.com>
  Created: August 2008

  This file is part of the GNUstep Base Library.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Library General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU Library General Public
  License along with this library; if not, write to the Free
  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

  AutogsdocSource: DBUSMessageIterator.m
*/

#ifndef _DBUSMessageIterator_H_
#define _DBUSMessageIterator_H_

/**
 * <p><code>DBUSMessageIterator</code> is a class that encapsulates the data
 * being sent over the network by D-Bus messages.
 * Each instance of DBUSMessage has a DBUSMessageIterator through which data
 * can be read or appended.
 */

#import <Foundation/NSObject.h>

#include <dbus/dbus.h>

@class DBUSMessage;

@interface DBUSMessageIterator : NSObject
{
  DBusMessageIter *_iter;
  //Used when a container has been opened.
  DBusMessageIter *_parent_iter;
  DBusMessage *msg;
}

/**
 * Returns an initialized iterator instance for the message aMsg.
 */
+ (id) iteratorWithMessage: (DBUSMessage *)aMsg;

/**
 * Returns an initialized iterator instance.
 */
+ (id) iterator;

/**
 * Initializes an iterator held by aMsg.
 */
- (id) initWithMessage: (DBUSMessage *)aMsg;

/**
 * Prepares the iterator to start reading the arguments of the message.
 * It must be called before attempting to read any arguments from a message or
 * getting its description.
 */
- (DBusMessageIter *) readIteratorInit;

/**
 * Prepares the iterator to allow adding arguments to the message.
 * It must be called before attempting to add any arguments to a message.
 */
- (DBusMessageIter *) appendIteratorInit;

/**
 * Opens an iterator that's a sub-iterator of anIter (Used when appending
 * container types -arrays, dicts, etc.-). Type is a D-Bus container type,
 * e.g: DBUS_TYPE_DICT_ENTRY, DBUS_TYPE_ARRAY, etc.
 * closeContainer should be called after adding the arguments to the
 * sub-iterator.
 */
- (DBUSMessageIterator *) openContainerFor: (DBUSMessageIterator *)anIter
                                  withType: (int)type;

/**
 * Opens an iterator that's a sub-iterator of anIter (used for appending to
 * container types -arrays, dicts, etc.-). Type is a D-Bus container type,
 * e.g: DBUS_TYPE_DICT_ENTRY, DBUS_TYPE_ARRAY, etc. Contained signature is used
 * when adding arguments to invariants, and it should be the type of the single
 * value contained inside the signature.
 * closeContainer should be called after adding the arguments to the
 * sub-iterator.
 */
- (DBUSMessageIterator *) openContainerFor: (DBUSMessageIterator *)anIter
                                  withType: (int)type
                        containedSignature: (const char*)sig;

/**
 * Opens an iterator that's a sub-iterator of anIter (used when reading from
 * container types).
 * closeContainer should _not_ be called after reading the arguments of the
 * sub-iterator.
 */
- (DBUSMessageIterator *) openContainerFor: (DBUSMessageIterator *)anIter;

/**
 * Closes an open container previously opened with openContainerFor.
 */
- (void) closeContainer;

/**
 * Returns the argument type the iterator currently points to.
 */
- (int) argType;

/**
 * Determines if there are more items in the iterator.
 */
- (BOOL) hasNext;

/**
 * Moves the iterator to the next field.
 */
- (BOOL) next;

/**
 * Append a BOOL.
 */
- (BOOL) appendBool: (BOOL)aBool;

/**
 * Read a BOOL. Advances the iterator position automatically, e.g: next.
 */
- (BOOL) readBool;

/**
 * Append a byte.
 */
- (BOOL) appendByte: (unsigned char)aByte;

/**
 * Read a byte. Advances the iterator position automatically, e.g: next.
 */
- (unsigned char) readByte;

/**
 * Append a NSString.
 */
- (BOOL) appendString: (NSString *)aString;

/**
 * Read a NSString. Advances the iterator position automatically, e.g: next.
 */
- (NSString *) readString;

/**
 * Append a NSDictionary.
 */
- (BOOL) appendDictionary: (NSDictionary *)aDictionary;

/**
 * Read a NSDictionary. Advances the iterator position automatically, e.g: next.
 */
- (NSDictionary *) readDictionary;

/**
 * Append an unsigned 32 bit integer.
 */
- (BOOL) appendUInt32: (unsigned int)anInt;

/**
 * Read an unsigned 32 bit integer. Advances the iterator position
 * automatically, e.g: next.
 */
- (unsigned int) readUInt32;
@end

#endif // _DBUSMessageIterator_H_
