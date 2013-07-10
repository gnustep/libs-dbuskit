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
#import "DKInterface.h"
#import "DKMethod.h"
#import "DKMethodReturn.h"
#import "DKIntrospectionParserDelegate.h"

#import <Foundation/NSData.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSXMLParser.h>
#import <Foundation/NSXMLNode.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

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

- (DBusObjectPathVTable)vTable
{
  return [DKPort _DBusDefaultObjectPathVTable];
}

- (BOOL)_loadIntrospectionFromFile: (NSString*)path
{
  NSData *data = [[NSData alloc] initWithContentsOfFile: path];
  if (data == nil)
  {
    return NO;
  }

  NSXMLParser *parser = [[NSXMLParser alloc] initWithData: data];
  DKIntrospectionParserDelegate *delegate =
    [[DKIntrospectionParserDelegate alloc] initWithParentForNodes: self]; 
  [parser setDelegate: delegate];
  NS_DURING
  {
    [parser parse];
  }
  NS_HANDLER
  {
    [data release];
    [parser release];
    [delegate release];
    [localException raise];
  }
  NS_ENDHANDLER
  [parser release];
  [delegate release];
  state = DK_CACHE_BUILT;
  [self _installAllInterfaces];
  return YES;
}

- (NSInvocation*)_invocationForIntrospect: (DKMethod*)method
{
  NSInvocation *inv = 
    [NSInvocation invocationWithMethodSignature: [method methodSignature]];
  [inv setTarget: self];
  [inv setSelector: @selector(Introspect)]; 
  return inv;
}

- (NSInvocation*)_invocationForMethod: (DKMethod*)method
{
  SEL selector = NSSelectorFromString([method selectorString]);
  if (NULL == selector)
  {
    return nil;
  }
  NSMethodSignature *sig = [object methodSignatureForSelector: selector]; 
  if (nil == sig)
  {
    return nil;
  }
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: sig];
  [invocation setTarget: object];
  [invocation setSelector: selector];
  return invocation;
}

- (DBusHandlerResult)handleDBusMessage: (DBusMessage*)message
{
  NSAssert(NULL != message, @"Message is NULL");
  BOOL isIntrospect = NO;  
  if (dbus_message_has_interface(message, DBUS_INTERFACE_INTROSPECTABLE) 
    || dbus_message_has_member(message, "Introspect"))
  {
    isIntrospect = YES;
  }
  const char *iface = dbus_message_get_interface(message);
  const char *mthod = dbus_message_get_member(message);
  DKInterface *interface = [[self _interfaces] objectForKey: [NSString stringWithUTF8String: iface]];
  if (interface == nil)
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }

  DKMethod *method = [[interface methods] objectForKey: [NSString stringWithUTF8String: mthod]];

  if (method == nil)
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }

  NSInvocation *inv = nil;
  if (isIntrospect)
  {
    inv = [self _invocationForIntrospect: method]; 
  }
  else
  {
    inv = [self _invocationForMethod: method];
  }
  if (nil == inv)
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }

  [DKMethodReturn replyToDBusMessage: message
                            forProxy: self
                              method: method
                          invocation: inv]; 
  
  return DBUS_HANDLER_RESULT_HANDLED;
}

- (void)_installClassPermittedMessages
{
	// Introspects the Obj-C class of the object
}


- (void)DBusBuildMethodCache
{
 /* [condition lock];
  if (WILL_BUILD_CACHE == state)
  {


    [condition unlock];
  }
  else
  {
    [condition unlock];
  }
  */
  if (DK_CACHE_BUILT > state)
  {
    state = DK_CACHE_BUILT; 
    [self _installAllInterfaces];
  }
}

- (NSXMLNode*)XMLNodeIncludingCompleteIntrospection: (BOOL)includeIntrospection
                                        forChildren: (BOOL)includeChildIntrospection
					   absolute: (BOOL)absolutePath
{
  NSArray *attributes = nil;
  NSMutableArray *childNodes = [NSMutableArray array];
  if ((0 < [[self _name] length]) || absolutePath)
  {
    NSString *theName = [self _name];
    if (absolutePath)
    {
      theName = [self _path];
    }
     attributes = [NSArray arrayWithObject: [NSXMLNode attributeWithName: @"name"
                                                             stringValue: theName]];
  }

  if (YES == includeIntrospection)
  {
    if (0 != [[self _interfaces] count])
    {
      NSEnumerator *ifEnum = [[self _interfaces] objectEnumerator];
      DKInterface *theIf = nil;
      while (nil != (theIf = [ifEnum nextObject]))
      {
	NSXMLNode *ifNode = [theIf XMLNode];
	if (nil != ifNode)
	{
	  [childNodes addObject: ifNode];
	}
      }
    }

    if (0 != [[self _children] count])
    {
      NSEnumerator *nodeEnum = [[self _children] objectEnumerator];
      DKObjectPathNode *child = nil;
      while (nil != (child = [nodeEnum nextObject]))
      {
	// For children, we no longer differentiate whether they should introspect
	// themselves or their own children, also we don't want absolute paths
	// in child names
	NSXMLNode *node = [child XMLNodeIncludingCompleteIntrospection: includeChildIntrospection
	                                                   forChildren: includeChildIntrospection
	                                                      absolute: NO];
	if (nil != node)
	{
	  [childNodes addObject: node];
	}
      }
    }
  }
  return [NSXMLNode elementWithName: @"node"
                           children: childNodes
                         attributes: attributes];
}

- (NSXMLNode*)XMLNodeIncludingCompleteIntrospection: (BOOL)includeIntrospection
                                           absolute: (BOOL)absolutePath
{
  return [self XMLNodeIncludingCompleteIntrospection: YES
                                         forChildren: includeIntrospection
                                            absolute: absolutePath];

}

- (NSXMLNode*)XMLNode
{
        return [self XMLNodeIncludingCompleteIntrospection: NO
                                                  absolute: YES];
}

- (NSString*)Introspect
{
  NSString *introspectionData = [NSString stringWithFormat: @"%@\n%@", kDKDBusDocType, [[self XMLNode] XMLString]];
  NSDebugMLog(@"Generated introspection data:\n%@", introspectionData);
  return introspectionData;
}


/*
 * These methods are only here because GCC does not take into account methods
 * implemented in superclasses when checking for protocol compliance.
 */

- (DKProxy*)proxyParent
{
  return [super proxyParent];
}

- (NSDictionary*)_children
{
  return [super _children];
}

- (NSDictionary*)_interfaces
{
  return [super _interfaces];
}

- (NSString*)_name
{
  return [super _name];
}

- (NSString*)_path
{
  return [super _path];
}

- (void)_removeChildNode: (id<DKObjectPathNode>)node
{
  [super _removeChildNode: node];
}

- (void)_addChildNode: (id<DKObjectPathNode>)node
{
  [super _addChildNode: node];
}

- (void)_addInterface: (DKInterface*)iface
{
  [super _addInterface: iface];
}
@end
