/** Declaration of private methods for DKProxy.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2010

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

#import "DBusKit/DKProxy.h"

#import "DKObjectPathNode.h"

@class DKInterface;

@interface DKProxy (DKProxyPrivate) <DKObjectPathNode>
- (DKPort*)_port;
- (DKEndpoint*)_endpoint;
- (NSString*)_service;
- (BOOL)_isLocal;
- (NSString*)_uniqueName;
@end

/* FIXME: Once we've got a dbuskit_make_protocol tool, replace this by a proper,
 * generated header for the org.freedesktop.DBus interface.
 */
@protocol DKDBusStub
- (NSString*)GetNameOwner: (NSString*)name;
@end

/**
 * _DKInterfaceIntrospectable is a prototype for the D-Bus
 * org.freedesktop.DBus.Introspectable. It will be added to the dispatch table
 * of a proxy because we need it to dispatch the initial introspection data.
 */
extern DKInterface *_DKInterfaceIntrospectable;
