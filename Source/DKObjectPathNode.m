/** Implementation of the DKObjectPathNode helper class.
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

#import "DKObjectPathNode.h"
#import "DKInterface.h"
#import "DKMethodReturn.h"
#import "DKProxy+Private.h"
#import "DKPort+Private.h"
#import "DKEndpoint.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLNode.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

@implementation DKObjectPathNode

- (id) initWithName: (NSString*)aName
             parent: (id)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }
  if (nil == aName)
  {
    [self release];
    return nil;
  }
  children = [NSMutableDictionary new];
  interfaces = [NSMutableDictionary new];
  return self;
}

- (void)_addInterface: (DKInterface*)interface
{
  NSString *ifName = [interface name];
  if (nil != name)
  {
    [interfaces setObject: interface
                   forKey: ifName];
  }
}

- (void)_addChildNode: (id<DKObjectPathNode>)node
{
  if (0 == [[node _name] length])
  {
    return;
  }
  [children setObject: node
               forKey: [node _name]];
}

- (void)_removeChildNode: (id<DKObjectPathNode>)node
{
  if (0 == [[node _name] length])
  {
    return;
  }
  [children removeObjectForKey: [node _name]];
}

- (NSString*)_path
{
  if ([parent conformsToProtocol: @protocol(DKObjectPathNode)])
  {
    NSString *parentPath = [parent _path];
    if ([@"/" isEqualToString: parentPath])
    {
      return [parentPath stringByAppendingString: [self name]];
    }
    else
    {
      return [NSString stringWithFormat: @"%@/%@", [parent _path], [self name]];
    }
  }
  return nil;
}

- (NSString*)_name
{
  return [self name];
}

- (NSDictionary*)_interfaces
{
  return [[interfaces copy] autorelease];
}

- (NSDictionary*)_children
{
  return [[children copy] autorelease];
}


- (DBusObjectPathVTable)vTable
{
  return [DKPort _DBusDefaultObjectPathVTable];
}

/*
 * This method is only here because GCC is to braindead to check whether a
 * superclass implementation provides a method declared by an adopted protocl.
 */
- (DKProxy*)proxyParent
{
  return [super proxyParent];
}

- (DKProxy*)proxy
{
  DKProxy *rootProxy = [self proxyParent];
  DKEndpoint *theEndpoint = [rootProxy _endpoint];
  NSString *theService = [rootProxy _service];
  return [[[DKProxy alloc] initWithEndpoint: theEndpoint
                                 andService: theService
                                    andPath: [self _path]] autorelease];
}

- (void)setChildren: (NSMutableDictionary*)newChildren
{
  ASSIGN(children,newChildren);
  [[children allValues] makeObjectsPerformSelector: @selector(setParent:) withObject: self];
}

- (void)setInterfaces: (NSMutableDictionary*)newInterfaces
{
  ASSIGN(interfaces,newInterfaces);
  [[interfaces allValues] makeObjectsPerformSelector: @selector(setParent:) withObject: self];
}

- (id)copyWithZone: (NSZone*)zone
{
  DKObjectPathNode *newNode = [super copyWithZone: zone];
  NSMutableDictionary *newIfs = nil;
  NSMutableDictionary *newChildren = nil;

  newIfs = [[NSMutableDictionary allocWithZone: zone] initWithDictionary: interfaces
                                                               copyItems: YES];
  newChildren = [[NSMutableDictionary allocWithZone: zone] initWithDictionary: children
                                                                    copyItems: YES];
  [newNode setChildren: newChildren];
  [newNode setInterfaces: newIfs];
  [newIfs release];
  [newChildren release];
  return newNode;
}

- (NSXMLNode*)XMLNodeIncludingCompleteIntrospection: (BOOL)includeIntrospection
                                        forChildren: (BOOL)includeChildIntrospection
					   absolute: (BOOL)absolutePath
{
  NSArray *attributes = nil;
  NSMutableArray *childNodes = [NSMutableArray array];
  if ((0 < [name length]) || absolutePath)
  {
    NSString *theName = name;
    if (absolutePath)
    {
      theName = [self _path];
    }
     attributes = [NSArray arrayWithObject: [NSXMLNode attributeWithName: @"name"
                                                             stringValue: theName]];
  }

  if (YES == includeIntrospection)
  {
    if (0 != [interfaces count])
    {
      NSEnumerator *ifEnum = [interfaces objectEnumerator];
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

    if (0 != [children count])
    {
      NSEnumerator *nodeEnum = [children objectEnumerator];
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

- (DBusHandlerResult)handleDBusMessage: (DBusMessage*)message
{
  NSInvocation *inv = nil;
  DKInterface *introspectableIf = nil;
  /*
   * A bunch of sanity checks:
   */
  NSDebugMLog(@"Received message for %s, member %s",
    dbus_message_get_interface(message),
    dbus_message_get_member(message));
  // The message shall not be NULL
  if (NULL == message)
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }

  // The message shall be a method call
  if (DBUS_MESSAGE_TYPE_METHOD_CALL != dbus_message_get_type(message))
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }

  // The message shall go to the introspectable interface
  if (FALSE == dbus_message_has_interface(message,
    DBUS_INTERFACE_INTROSPECTABLE))
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }

  // It shall invoke the Introspect() method
  if (FALSE == dbus_message_has_member(message,"Introspect"))
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }
  NSDebugMLog(@"Yes, will handle this message");
  introspectableIf = [interfaces objectForKey: [_DKInterfaceIntrospectable name]];
  if (nil == introspectableIf)
  {
    introspectableIf = [_DKInterfaceIntrospectable copy];
    [self _addInterface: introspectableIf];
    // remove extra retain count from -copy:
    [introspectableIf release];
  }

  inv = [NSInvocation invocationWithMethodSignature: [self methodSignatureForSelector: @selector(Introspect)]];
  [inv setTarget: self];
  [inv setSelector: @selector(Introspect)];

  [DKMethodReturn replyToDBusMessage: message
                            forProxy: self
                              method: [introspectableIf DBusMethodForSelector: @selector(Introspect)]
                          invocation: inv];
  // TODO: Send the message
  return DBUS_HANDLER_RESULT_HANDLED;
}

- (void)dealloc
{
  [children release];
  [interfaces release];
  [super dealloc];
}
@end


@implementation DKProxyStandin

- (id)initWithEndpoint: (DKEndpoint*)anEndpoint
               service: (NSString*)aService
                  path: (NSString*)aPath
{
  if (nil == (self = [super initWithName: @"standin"
                                  parent: nil]))
  {
    return nil;
  }

  if (NO == (anEndpoint && [aService length]))
  {
    [self release];
    return nil;
  }

  if (0 == [aPath length])
  {
    aPath = @"/";
  }

  ASSIGN(endpoint, anEndpoint);
  ASSIGN(service, aService);
  ASSIGN(path, aPath);
  return self;
}

- (DKEndpoint*)_endpoint
{
  return endpoint;
}

- (NSString*)_service
{
  return service;
}

- (NSString*)_path
{
  return [[path copy] autorelease];
}

- (DKProxyStandin*)proxyParent
{
  return self;
}

- (DKProxy*)proxy
{
  return [[[DKProxy alloc] initWithEndpoint: endpoint
                                 andService: service
                                    andPath: path] autorelease];
}



- (void)dealloc
{
  DESTROY(endpoint);
  DESTROY(service);
  DESTROY(path);
  [super dealloc];
}
@end


@implementation DKRootObjectPathNode

- (id)initWithPort: (DKPort*)thePort
{
  // We reuse the parent ivar to store the port
  if (nil == (self = [super initWithName: @"/"
                                 parent: (id)thePort]))
  {
    return nil;
  }
  // We always need the introspectable interface:
  [self setInterfaces: [NSDictionary dictionaryWithObject: [[_DKInterfaceIntrospectable copy] autorelease]
                                                   forKey: [_DKInterfaceIntrospectable name]]];
  return self;
}
- (NSString*)_path
{
  return @"/";
}

- (DKPort*)_port
{
  // We reuse the parent ivar to store the port
  return (DKPort*)parent;
}

- (DKEndpoint*)_endpoint
{
  return [(DKPort*)parent endpoint];
}
- (DKProxy*)proxyParent
{
  return (DKProxy*)self;
}

- (id)parent
{
  // This can only be used as a root
  return nil;
}

- (void)setParent: (id)theParent
{
  //NoOp, we are a root.
}

- (BOOL)_isLocal
{
  return YES;
}
@end
