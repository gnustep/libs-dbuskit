/** Implementation of the DKPort class for NSConnection integration.
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

#import "DBusKit/DKPort.h"
#import "DKEndpoint.h"

#include <dbus/dbus.h>

static Class DKPortAbstractClass;
static Class DKPortConcreteClass;

@implementation DKPort
+ (void)initialize
{
  /*
   * Preload the class pointers to avoid expensive class message sends on every
   * +port call.
   */
  Class abstractClass = [DKPort class];
  if (self == abstractClass)
  {
    DKPortAbstractClass = abstractClass;
    DKPortConcreteClass = [DKSessionBusPort class];
  }
}

+ (NSPort*)port
{
  if (self == DKPortAbstractClass)
  {
    return [[[DKPortConcreteClass alloc] init] autorelease];
  }
  else
  {
    return [[[self alloc] init] autorelease];
  }
}

- (id) initWithRemote: (NSString*)aRemote
{
  // We can just modify the isa pointer because the abstract and concrete
  // classes share the same ivar layout.
  if (DKPortAbstractClass == isa)
  {
    isa = DKPortConcreteClass;
    // Call again with the proper implementation:
    return [self initWithRemote: aRemote];
  }

  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGNCOPY(remote, aRemote);
  return self;
}

- (id) init
{
  return [self initWithRemote: nil];
}

- (void) dealloc
{
  [endpoint release];
  [remote release];
  [super dealloc];
}
@end

@implementation DKSessionBusPort
- (id)initWithRemote: (NSString*)aRemote
{
  if (nil == (self = [super initWithRemote: aRemote]))
  {
    return nil;
  }
  endpoint = [[DKEndpoint alloc] initWithWellKnownBus: DBUS_BUS_SESSION];
  return self;
}
@end


@implementation DKSystemBusPort
- (id)initWithRemote: (NSString*)aRemote
{
  if (nil == (self = [super initWithRemote: aRemote]))
  {
    return nil;
  }
  endpoint = [[DKEndpoint alloc] initWithWellKnownBus: DBUS_BUS_SYSTEM];
  return self;
}
@end
