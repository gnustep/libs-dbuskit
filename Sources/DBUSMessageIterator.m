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

*/

#import "DBUSMessageIterator.h"
#import "DBUSMessage.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

@interface DBUSMessageIterator (Private)

/**
 * Returns the D-Bus iterator used for reading or adding arguments from the
 * message (this is not an objc object). Its function varies depending on a
 * previous call to appendIteratorInit or readIteratorInit.
 */

- (DBusMessageIter *) iterator;

/**
 * Read any basic D-Bus type from the iterator (for container types a
 * subiterator must be opened -read initWithIterator:- and then this method
 * can be used to read arguments from it).
 */
- (dbus_uint64_t) readBasic;

/**
 * Add an object argument to the message iterator.
 * Note: _many_ object types haven't been tested.
 */
- (void) appendObject: (id)anObj;

/**
 * Read an object argument from the message iterator.
 * Note: _many_ object types haven't been tested.
 */
- (id) readObject;

@end

@implementation DBUSMessageIterator

+ (id) iteratorWithMessage: (DBUSMessage *)aMsg
{
  return AUTORELEASE([[self alloc] initWithMessage: aMsg]);
}

+ (id) iterator
{
  return AUTORELEASE([[self alloc] init]);
}

- (id) init
{
  _iter = dbus_new(DBusMessageIter, 1);

  return [super init];
}

- (id) initWithMessage: (DBUSMessage *)aMsg
{
  if (aMsg)
    {
      msg = [aMsg message];
      dbus_message_ref(msg);
    }
  else
    {
      return nil;
    }
  [self init];

  return self;
}

- (void) dealloc
{
  dbus_free(_iter);
  if (NULL != msg)
    {
      dbus_message_unref(msg);
    }
  [super dealloc];
}

- (DBusMessageIter *) readIteratorInit
{
  if (dbus_message_iter_init(msg, _iter))
    {
      return _iter;
    }

  return NULL;
}

- (DBusMessageIter *) appendIteratorInit
{
  dbus_message_iter_init_append(msg, _iter);

  return _iter;
}

- (DBUSMessageIterator *) openContainerFor: (DBUSMessageIterator *)anIter
                                  withType: (int)type
{
  return [self openContainerFor: anIter
                       withType: type
             containedSignature: NULL];
}

- (DBUSMessageIterator *) openContainerFor: (DBUSMessageIterator *)anIter
                                  withType: (int)type
                        containedSignature: (const char*) aSig
{
  _parent_iter = [anIter iterator];
  dbus_message_iter_open_container(_parent_iter,
                                   type,
                                   aSig,
                                   _iter);
  return self;
}

- (DBUSMessageIterator *) openContainerFor: (DBUSMessageIterator *)anIter
{
  _parent_iter = [anIter iterator];
  dbus_message_iter_recurse(_parent_iter, _iter);

  return self;
}

- (void) closeContainer
{
  if (_parent_iter)
    {
      dbus_message_iter_close_container(_parent_iter, _iter);
    }
}


- (int) argType
{
  int type;

  type = dbus_message_iter_get_arg_type([self iterator]);

  NSDebugMLLog(@"DBUSMessageIterator", @"Arg type: %d", type);

  return type;
}

- (BOOL) hasNext;
{
  BOOL res;

  res = dbus_message_iter_has_next([self iterator]) ? YES : NO;

  NSDebugMLLog(@"DBUSMessageIterator", @"hasNext: %s", res ? "YES" : "NO");
  return res;
}

- (BOOL) next;
{
  return (BOOL)dbus_message_iter_next([self iterator]);
}

- (BOOL) appendBool: (BOOL)aBool;
{
  BOOL res = YES;
  dbus_bool_t buf;

  buf = (dbus_bool_t)aBool;

  if (!dbus_message_iter_append_basic([self iterator],
                                      DBUS_TYPE_BOOLEAN,
                                      &buf))
    {
      NSLog(@"Out Of Memory!\n");
      res = NO;
    }

  return res;
}

- (BOOL) readBool;
{
  dbus_bool_t buf;

  buf = (dbus_bool_t)[self readBasic];

  return (BOOL)buf;
}

- (BOOL) appendByte: (unsigned char)aByte;
{
  BOOL res = YES;

  if (!dbus_message_iter_append_basic([self iterator],
                                      DBUS_TYPE_BYTE,
                                      &aByte))
    {
      NSLog(@"Out Of Memory!\n");
      res = NO;
    }

  return res;
}

- (unsigned char) readByte
{
  unsigned char buf;

  buf = (unsigned char)[self readBasic];

  return buf;
}

- (BOOL) appendDictionary: (NSDictionary *)aDict
{
  DBUSMessageIterator *sub;
  NSArray *keys;
  int i, count;
  id key, value;

  keys = [aDict allKeys];
  count = [keys count];
  for (i = 0; i < count; i++)
  {
    key = [keys objectAtIndex: i];
    value = [aDict objectForKey: key];
    sub = [DBUSMessageIterator iterator];

    [sub openContainerFor: self 
                 withType: DBUS_TYPE_DICT_ENTRY];

    [sub appendObject: value];
    [sub appendObject: key];

    [sub closeContainer];
  }

  return YES;
}

- (NSDictionary *) readDictionary
{
  DBUSMessageIterator *sub;
  NSDictionary *dict = nil;
  id obj1, obj2;

  sub = [DBUSMessageIterator iterator];
 
  [self readIteratorInit];
  if (DBUS_TYPE_DICT_ENTRY == [self argType])
    {
      [sub openContainerFor: self];
      obj1 = [sub readObject];
      obj2 = [sub readObject];

      dict = [NSDictionary dictionaryWithObject: obj1
                                         forKey: obj2];
    }

  return dict;
}

- (BOOL) appendString: (NSString *)aString;
{
  BOOL res = YES;
  const char *str;

  str = [aString UTF8String];

  if (!dbus_message_iter_append_basic([self iterator],
                                      DBUS_TYPE_STRING,
                                      &str))
    {
      NSLog(@"Out Of Memory!\n");
      res = NO;
    }

  return res;
}

- (NSString *) readString
{
  dbus_uint32_t buf;
  NSString *res;

  buf = (dbus_uint32_t)[self readBasic];
  if (buf)
    {
      res = [NSString stringWithUTF8String: (char *)buf];
    }
  else
    {
      res = nil;
    }

  return res;
}

- (BOOL) appendUInt32: (unsigned int)anInt;
{
  BOOL res = YES;

  if (!dbus_message_iter_append_basic([self iterator],
                                      DBUS_TYPE_UINT32,
                                      &anInt))
    {
      NSLog(@"Out Of Memory!\n");
      res = NO;
    }

  return res;
}

- (unsigned int) readUInt32;
{
  unsigned int buf;

  buf = (unsigned int)[self readBasic];

  return buf;
}

- (NSString *) description
{
  char *rSig;

  rSig = dbus_message_iter_get_signature([self iterator]);

  return [NSString stringWithUTF8String: rSig];
}

@end

@implementation DBUSMessageIterator (Private)

- (DBusMessageIter *) iterator
{
  return _iter;
}

- (dbus_uint64_t) readBasic
{
  dbus_uint64_t value;

  if (DBUS_TYPE_INVALID != [self argType])
    {
      dbus_message_iter_get_basic([self iterator], &value);
    }
  else
    {
      //FIXME: this might present a problem -tests look fine though-
      value = 0;
    }

  [self next];

  return value;
}

- (void) appendObject: (id)anObj
{
  //TODO: many types left
  if ([anObj isKindOfClass: [NSString class]])
    {
      [self appendString: anObj];
    }
  //else if ([anObj isKindOfClass: [NSValue class]])
    //{
      //[self appendNSValue: anObj];
    //}
}

- (id) readObject
{
  int type;
  id obj;

  //TODO: many types left
  type = [self argType];

  switch(type)
    {
    case DBUS_TYPE_STRING:
      obj = [self readString];
      break;
    }

  return obj;
}

@end
