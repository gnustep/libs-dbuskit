/** Implementation of DKArgument class for boxing and unboxing D-Bus types.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>
#import "DBusKit/DKProxy.h"
#import "DKArgument.h"

#include <dbus/dbus.h>

NSString *DKArgumentDirectionIn = @"in";
NSString *DKArgumentDirectionOut = @"out";



static Class
DKObjCClassForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT64:
    case DBUS_TYPE_DOUBLE:
      return [NSNumber class];
    case DBUS_TYPE_STRING:
      return [NSString class];
    case DBUS_TYPE_OBJECT_PATH:
      return [DKProxy class];
    case DBUS_TYPE_SIGNATURE:
      return [DKArgument class];
    // Some DBUS_TYPE_ARRAYs will actually be dictionaries if they contain
    // DBUS_TYPE_DICT_ENTRies.
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
      return [NSArray class];
    // The following types have no explicit representation, they will either not
    // be handled at all, or their boxing is determined by the container resp.
    // the contained type.
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_VARIANT:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      break;
  }
  return Nil;
}

static char*
DKUnboxedObjCTypeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return @encode(char);
    case DBUS_TYPE_BOOLEAN:
      return @encode(BOOL);
    case DBUS_TYPE_INT16:
      return @encode(int16_t);
    case DBUS_TYPE_UINT16:
      return @encode(uint16_t);
    case DBUS_TYPE_INT32:
      return @encode(int32_t);
    case DBUS_TYPE_UINT32:
      return @encode(uint32_t);
    case DBUS_TYPE_INT64:
      return @encode(int64_t);
    case DBUS_TYPE_UINT64:
      return @encode(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return @encode(double);
    case DBUS_TYPE_STRING:
      return @encode(char*);
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return @encode(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return '\0';
  }
  return '\0';
}

/**
 *  DKArgument encapsulates D-Bus argument information
 */
@implementation DKArgument
- (id) initWithIterator: (DBusSignatureIter*)_iterator
                   name: (NSString*)_name
                 parent: (id)_parent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  memcpy(&iterator, _iterator, sizeof(DBusSignatureIter));

  DBusType = dbus_signature_iter_get_current_type(&iterator);

  if ((dbus_type_is_container(DBusType))
    && (![self isKindOfClass: [DKContainerTypeArgument class]]))
  {
    NSDebugMLog(@"Incorrectly initalized a non-container argument with a container type, reinitializing as container type.");
    [self release];
    return [[DKContainerTypeArgument alloc] initWithIterator: _iterator
                                                        name: _name
                                                      parent: _parent];
  }
  ASSIGNCOPY(_name, name);
  objCEquivalent = DKObjCClassForDBusType(DBusType);
  parent = _parent;
  return self;
}

- (id)initWithDBusSignature: (const char*)DBusTypeString
                       name: (NSString*)_name
                     parent: (id)_parent
{
  if (!dbus_signature_validate_single(DBusTypeString, NULL))
  {
    NSWarnMLog(@"Not a single D-Bus type signature ('%s'), ignoring argument", DBusTypeString);
    return nil;
  }

  DBusSignatureIter myIter;
  dbus_signature_iter_init(&myIter, DBusTypeString);
  return [self initWithIterator: &myIter
                           name: _name
                         parent: _parent];
}



- (void)setObjCEquivalent: (Class)class
{
  objCEquivalent = class;
}

- (char*) unboxedObjCTypeChar
{
  return DKUnboxedObjCTypeForDBusType(DBusType);
}
- (BOOL) isContainerType
{
  return NO;
}

- (void)dealloc
{
  parent = nil;
  [name release];
  [super dealloc];
}
@end

@implementation DKContainerTypeArgument

- (id)initWithDBusSignature: (const char*)DBusTypeString
                       name: (NSString*)_name
                     parent: (id)_parent
{
  if (nil == (self = [super initWithDBusSignature: DBusTypeString
                                             name: _name
                                           parent: _parent]))
  {
    [self release];
    return nil;
  }
  children = [[NSMutableArray alloc] init];
  //TODO: Create recurive iterator to collect subtypes of the argument.
  return self;
}
- (char*) unboxedObjCTypeChar
{
  return @encode(id);
}

- (BOOL) isContainerType
{
  return YES;
}

- (void)dealloc
{
  [children release];
  [super dealloc];
}
@end;
