/** Category on NSConnection to facilitate D-Bus integration
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

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

#import "DBusKit/NSConnection+DBus.h"
#import "DBusKit/DKPort.h"
#import "DKProxy+Private.h"

#import <Foundation/NSConnection.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#define INCLUDE_RUNTIME_H
#import "config.h"
#undef INCLUDE_RUNTIME_H

@interface DKPort (DKPortPrivate)
- (BOOL)hasValidRemote;
- (void)_setObject: (id)obj
            atPath: (NSString*)path;
@end

static SEL rootProxySel;
static IMP _DKNSConnectionRootProxy;
static SEL setRootObjectSel;
static IMP _DKNSConnectionSetRootObject;


@implementation NSConnection (DBusKit)
+ (void)load
{
  Method oldRootProxyMethod, newRootProxyMethod;
  Method oldSetRootObjectMethod, newSetRootObjectMethod;

  /*
   * We do some devious patching and replace some method implementations in
   * NSConnection with the ones from this category.
   */
  rootProxySel = @selector(rootProxy);
  setRootObjectSel = @selector(setRootObject:);
  oldRootProxyMethod =
    class_getInstanceMethod(objc_getClass("NSConnection"), rootProxySel);
  newRootProxyMethod =
    class_getInstanceMethod(objc_getClass("NSConnection"),
      @selector(_DKRootProxy));
  oldSetRootObjectMethod =
    class_getInstanceMethod(objc_getClass("NSConnection"), setRootObjectSel);
  newSetRootObjectMethod =
    class_getInstanceMethod(objc_getClass("NSConnection"),
      @selector(_DKSetRootObject:));
  _DKNSConnectionRootProxy = method_getImplementation(oldRootProxyMethod);
  method_exchangeImplementations(oldRootProxyMethod, newRootProxyMethod);

 _DKNSConnectionSetRootObject =
    method_getImplementation(oldSetRootObjectMethod);
  method_exchangeImplementations(oldSetRootObjectMethod, newSetRootObjectMethod);
}

- (NSDistantObject*)_DKRootProxy
{
  id sp = [self sendPort];
  if (NO == [sp isKindOfClass: [DKPort class]])
  {
    return _DKNSConnectionRootProxy(self, rootProxySel);
  }
  else
  {
    return (NSDistantObject*)[self proxyAtPath: @"/"];
  }
}

- (void)_DKSetRootObject: (id)obj
{
  id rp = [self receivePort];
  if (YES == [rp isKindOfClass: [DKPort class]])
  {
    [self setObject: obj
             atPath: @"/"];
  }
  _DKNSConnectionSetRootObject(self, setRootObjectSel, obj);
}

- (void)setObject: (id)obj
           atPath: (NSString*)path
{
  id rp = [self receivePort];
  if (NO == [rp isKindOfClass: [DKPort class]])
  {
    if ([@"/" isEqualToString: path])
    {
      _DKNSConnectionSetRootObject(self, setRootObjectSel, obj);
    }
    return;
  }
  [(DKPort*)rp _setObject: obj
                   atPath: path];
}

- (DKProxy*)proxyAtPath: (NSString*)path
{
  id sp = [self sendPort];
  if (NO == [sp isKindOfClass: [DKPort class]])
  {
    NSWarnMLog(@"Not attempting to find proxy at path '%@' for non D-Bus port", path);
    return nil;
  }

  if (NO == [sp hasValidRemote])
  {
    return nil;
  }

  return [DKProxy proxyWithPort: sp
                           path: path];
}
/*
+ (DKProxy*)     proxyAtPath: (NSString*)path
forConnectionWithDBusService: (NSString*)serviceName
                         bus: (DKDBusBusType)busType
{
  DKPortNameserver *ns = [DKPortNameServer sharedPortNameServerForBusType: busType];
  DKPort *sp = [ns portForName: serviceName];
  NSConnection *c = [self connectionWithReceivePort: [DKPort portForBusType: busType]
                                           sendPort: sp];
  return [c proxyAtPath: path];
  return nil;
}

+ (DKProxy*) rootProxyForConnectionWithDBusService: (NSString*)serviceName
                                               bus: (DKDBusBusType)busType
{
  return [self   proxyAtPath: @"/"
forConnectionWithDBusService: serviceName
                         bus: busType];
}
*/
@end
