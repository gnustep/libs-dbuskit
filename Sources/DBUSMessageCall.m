/* -*-objc-*-
  Language bindings for d-bus
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Fred Kiefer <FredKiefer@gmx.de>
  Modified by: Ricardo Correa <r.correa.r@gmail.com>
  Created: January 2007

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

#import "DBUSMessageCall.h"

#import <Foundation/NSInvocation.h>
#import <Foundation/NSString.h>

#include <dbus/dbus.h>


static NSString* _methodNameForSelector(SEL selector)
{
  NSString *name;

  name = NSStringFromSelector(selector);
  return [name stringByReplacingString: @":" withString: @""];
}

@implementation DBUSMessageCall

- (id) initMessageCallWithName: (NSString*)name
                          path: (NSString*)path
                     interface: (NSString*)interface
                      selector: (SEL)selector
{
  NSString *mName;

  mName = _methodNameForSelector (selector);
  // create a new method call and check for errors
  msg = dbus_message_new_method_call([name UTF8String], //target for the method
                                     [path UTF8String], //object to call
                                     [interface UTF8String], //interface to call
                                     [mName UTF8String]); //method name

  return [self initWithMessage: msg];
}

- (BOOL) setupInvocation: (NSInvocation *)inv
{
  DBusMessageIter args;
  NSMethodSignature *sig;
  int count, i;

  // append arguments
  dbus_message_iter_init_append(msg, &args);

  sig = [inv methodSignature];
  count = [sig numberOfArguments];
  for (i=2; i<count; i++)
    {
      const char *type;

      type = [sig getArgumentTypeAtIndex: i];
      switch (type[0])
        {
        case _C_CHARPTR:
            {
              char *param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_STRING, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_LNG:
            {
              long param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_INT64, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_ULNG:
            {
              unsigned long param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_UINT64, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_INT:
            {
              int param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_INT32, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_UINT:
            {
              unsigned int param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_UINT32, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_SHT:
            {
              short param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_INT16, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_USHT:
            {
              unsigned short param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_UINT16, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_CHR:
          break;
        case _C_UCHR:
            {
              unsigned char param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_BYTE, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_FLT:
          break;
        case _C_DBL:
            {
              double param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args,
                                                  DBUS_TYPE_DOUBLE, &param))
                {
                  NSLog(@"Out Of Memory!\n");
                  return NO;
                }
            }
          break;
        case _C_PTR:
           // FIXME: cannot handle pointers!
          break;
        case _C_ID:
          // FIXME: cannot handle objects!
          // DBUS_TYPE_OBJECT_PATH or DBUS_TYPE_OBJECT_PATH_AS_STRING
          break;
        case _C_VOID:
          // not possible
          break;
        case _C_CLASS:
          // not possible
          break;
        case _C_SEL:
          // not possible
          // DBUS_TYPE_SIGNATURE ?
          break;
        case _C_STRUCT_B:
          // not possible
          // DBUS_TYPE_STRUCT
          break;
        case _C_UNION_B:
          // not possible
          // DBUS_TYPE_VARIANT
          break;
        case _C_ARY_B:
          // not possible
          // DBUS_TYPE_ARRAY
          break;

        default:
          break;
        }
    }

  return YES;
}

@end
