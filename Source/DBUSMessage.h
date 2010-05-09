/* -*-objc-*- 
   Language bindings for d-bus
   Copyright (C) 2007 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
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
#ifndef _DBUS_H_DBUSMessage

#include "dbus/dbus.h"
#include <Foundation/NSObject.h>

@class NSString;

@interface DBUSMessage: NSObject
{
  DBusMessage *msg;
}

+ (NSString*) methodNameForSelector: (SEL)selector;
+ (id) dbusMessageFor: (DBUSProxy*)object
           invocation: (NSInvocation*)inv;

- (id) initWith: (DBusMessage *)aMSG;
- (id) initMethodCallWithTarget: (NSString*)target
                           name: (NSString*)name
                      interface: (NSString*)interface
                  andMethodName: (NSString*)methodName;
- (BOOL) setupInvocation: (NSInvocation*)inv;
- (DBusMessage*) msg;
- (BOOL) getResultInto: (NSInvocation*)inv;

@end

#endif // _DBUS_H_DBUSMessage
