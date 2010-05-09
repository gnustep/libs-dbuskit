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

#import "DBUSMessageReturn.h"

#import "DBUSMessageIterator.h"

#import <Foundation/NSDebug.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>

#include <dbus/dbus.h>

@implementation DBUSMessageReturn

- (BOOL) putResultInto: (NSInvocation *)inv
{
  DBUSMessageIterator *iter;

  iter = [DBUSMessageIterator iteratorWithMessage: self];

  if (iter)
    {
      int type;

      [iter readIteratorInit];
      type = [iter argType];

      switch (type)
        {
        case DBUS_TYPE_INVALID:
          break;
        case DBUS_TYPE_BOOLEAN:
            {
              BOOL res;

              res = [iter readBool];
              [inv setReturnValue: &res];
            }
          break;
        case DBUS_TYPE_UINT32:
            {
              dbus_uint32_t res;

              res = [iter readUInt32];
              [inv setReturnValue: &res];
            }
          break;
        case DBUS_TYPE_STRING:
            {
              NSString *val;
              const char *res; 

              val = [iter readString];

              res = [val UTF8String];
              [inv setReturnValue: &res];
            }
          // TODO: add all of the other types
        }
    }
  else
    {
      NSDebugLLog(@"DBUSMessageReturn", @"Message has no return arguments!\n");
    }

  return YES;
}

@end
