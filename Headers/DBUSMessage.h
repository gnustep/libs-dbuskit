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

#ifndef _DBUSMessage_H_
#define _DBUSMessage_H_

#import <Foundation/NSObject.h>

#include <dbus/dbus.h>

@interface DBUSMessage : NSObject
{
  DBusMessage *msg;
}

/**
 * Initialize the message with the D-Bus object aMsg (not an objc object).
 */
- (id) initWithMessage: (DBusMessage *)aMsg;

/**
 * Returns the D-Bus message object for this instance.
 */
- (DBusMessage *) message;

@end

#endif // _DBUSMessage_H_
