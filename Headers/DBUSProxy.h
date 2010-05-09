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

#ifndef _DBUSProxy_H_
#define _DBUSProxy_H_

#include <Foundation/NSProxy.h>

@class NSString;
@class DBUSConnection;
@class DBUSIntrospector;

@interface DBUSProxy: NSProxy
{
  DBUSConnection *conn;
  NSString *name;
  NSString *path;
  NSString *interface;
  DBUSIntrospector *introspector;
  Protocol *protocol;
}

- (id) init;
- (id) initForConnection: (DBUSConnection *)connection
                withName: (NSString *)theName
                    path: (NSString *)thePath
               interface: (NSString *)theInterface;
- (NSString *) name;
- (NSString *) path;
- (NSString *) interface;
- (DBUSConnection *) connectionForProxy;
- (BOOL) isInstance;

@end

//@interface DBUSProxy (org.freedesktop.DBus.Introspectable)
@interface DBUSProxy (Introspectable)
- (char *) Introspect;
@end

#endif // _DBUSProxy_H_
