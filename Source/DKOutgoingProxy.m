/** Implementation of the DKOutgoingProxy class for exporting objects via D-Bus

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
   */

#import "DKOutgoingProxy.h"
#import "DKPort+Private.h"
#import <Foundation/NSLock.h>
#import <Foundation/NSException.h>
#if __OBJC_GC__
#import <Foundation/NSGarbageCollector.h>
#endif

@implementation DKOutgoingProxy
+ (id)proxyWithName: (NSString*)aName
             parent: (id<DKObjectPathNode>)parentNode
             object: (id)anObject
{
  return [[[self alloc] initWithName: aName
                              parent: parentNode
                              object: anObject] autorelease];
}


- (id)initWithName: (NSString*)aName
            parent: (id<DKObjectPathNode>)parentNode
            object: (id)anObject
{
  DKPort *aPort = nil;
  NSString *parentPath = [parentNode _path];
  NSString *aPath = nil;
  NSRange slashRange = [aName rangeOfString: @"/"];
  while (nil != parentNode)
  {
    if ([(id<NSObject>)parentNode respondsToSelector: @selector(_port)])
    {
      aPort = [(DKProxy*)parentNode _port];
      break;
    }
    else if ([(id<NSObject>)parentNode respondsToSelector: @selector(parent)])
    {
      parentNode = [(DKObjectPathNode*)parentNode parent];
    }
    else
    {
      parentNode = nil;
    }
  }

  if (nil == aPort)
  {
    [self release];
    return nil;
  }

  if (0 == slashRange.location)
  {
    // Strip leading slashes from the last path component
    aName = [aName substringFromIndex: slashRange.length];
  }

  if (0 == [parentPath length])
  {
    parentPath = @"/";
  }

  aPath = [parentPath stringByAppendingPathComponent: aName];

  if (nil == (self = [super initWithPort: aPort
                                    path: aPath]))
  {
    return nil;
  }

  ASSIGN(object, anObject);
  busLock = [NSRecursiveLock new];
  return self;

}

- (NSString*)descriptionWithLocale: (NSLocale*)locale
{
  return [NSString stringWithFormat: @"<DKOutgoingProxy at %@ for %@>", [self  _path], object];
}

- (NSString*)description
{
  return [self descriptionWithLocale: nil];
}

- (BOOL)_isLocal
{
  return YES;
}

- (void)_exportDBusRefCountInterface: (BOOL)doExport
{
  // TODO: implement
}


- (BOOL)_DBusIsAutoExported
{
  return _DBusIsAutoExported;
}

- (void)_setDBusIsAutoExported: (BOOL)yesno
{
  if (__sync_bool_compare_and_swap(&_DBusIsAutoExported, NO, yesno))
  {
    [self _exportDBusRefCountInterface: YES];
  }
  else if ((NO == yesno) && (0 == _DBusRefCount))
  {
    [self _exportDBusRefCountInterface: NO];
  }

}
- (NSUInteger)_DBusRefCount
{
  return _DBusRefCount;
}

- (void)_DBusRetain
{
  __sync_fetch_and_add(&_DBusRefCount, 1);
  if (0 < _DBusRefCount)
  {
    [busLock lock];
    if (0 == _DBusRefCount)
    {
      [busLock unlock];
      return;
    }
    NS_DURING
    {
      // We must expose the refcount interface to the bus in this case.
      [self _exportDBusRefCountInterface: YES];
      /*
       * In a gargabe collected environment, we must disable collection of ourselves
       * until no client on the bus needs us anymore.
       */
#     if __OBJC_GC__
      [[NSGarbageCollector defaultCollector] disableCollectorForPointer: (void*)self];
#     endif

    }
    NS_HANDLER
    {
      [busLock unlock];
      [localException raise];
    }
    NS_ENDHANDLER
    [busLock unlock];
  }
}

- (void)_DBusRelease
{
  __sync_fetch_and_sub(&_DBusRefCount, 1);
  if (0 == _DBusRefCount)
  {
    [busLock lock];
    if (0 != _DBusRefCount)
    {
      [busLock unlock];
      return;
    }
    NS_DURING
    {
      if (NO == _DBusIsAutoExported)
      {
        /*
         * If we are not an autoexported object, but instead a transient
         * reference to a manually exported object, we just disable the
         * refcount interface again and do not try to unpublish ourselves.
         */
        [self _exportDBusRefCountInterface: NO];
      }
      else
      {
        /*
         * Now we're sure that we are meant to be removed from the bus. But before
         * we ask the port to unpublish us, we retain ourselves so that we are not
         * deallocated while we are still doing cleanup.
         */
        [self retain];
        [[self _port] _setObject: nil
                          atPath: [self _path]];
        // In GC mode, also tell the garbage collector that we are eligible for
        // collection again.
#       if __OBJC_GC__
        [[NSGarbageCollector defaultCollector] enableCollectorForPointer: (void*)self];
#       endif
      }
    }
    NS_HANDLER
    {
      [busLock unlock];
      [self release];
      [localException raise];
    }
    NS_ENDHANDLER
    [busLock unlock];
    [self release];
  }
}

@end
