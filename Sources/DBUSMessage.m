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

#import "DBUSMessage.h"

#import <Foundation/NSString.h>

@implementation DBUSMessage

- (id) initWithMessage: (DBusMessage *)aMsg
{
  if (NULL == aMsg)
    {
      RELEASE(self);
      return nil;
    }

  msg = aMsg;
  dbus_message_ref(msg);

  [self init];

  return self;
}

- (void) dealloc
{
  if (NULL != msg)
    {
      // free message
      dbus_message_unref(msg);
    }
  [super dealloc];
}

- (NSString *) description
{
  const char *rSig;

  rSig = dbus_message_get_signature(msg);

  return [NSString stringWithUTF8String: rSig];
}

- (DBusMessage *) message
{
  return msg;
}

@end
