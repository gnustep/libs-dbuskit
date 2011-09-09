/** Implementation of the DKObjectPathNode helper class.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: Jly 2010

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
#import "DKProxy+Private.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

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
  children = [NSMutableArray new];
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

- (void)_addChildNode: (DKObjectPathNode*)node
{
  [children addObject: node];
}

- (NSString*)_path
{
  if ([parent conformsToProtocol: @protocol(DKObjectPathNode)])
  {
    return [NSString stringWithFormat: @"%@/%@", [parent _path], [self name]];
  }
  return nil;
}

- (NSDictionary*)_interfaces
{
  return [[interfaces copy] autorelease];
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

- (void)setChildren: (NSMutableArray*)newChildren
{
  ASSIGN(children,newChildren);
  [children makeObjectsPerformSelector: @selector(setParent:) withObject: self];
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
  NSMutableArray *newChildren = nil;

  newIfs = [[NSMutableDictionary allocWithZone: zone] initWithDictionary: interfaces
                                                               copyItems: YES];
  newChildren = [[NSMutableArray allocWithZone: zone] initWithArray: children
                                                          copyItems: YES];
  [newNode setChildren: newChildren];
  [newNode setInterfaces: newIfs];
  [newIfs release];
  [newChildren release];
  return newNode;
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
