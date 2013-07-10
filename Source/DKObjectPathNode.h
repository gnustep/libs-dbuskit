/** Interface for the DKObjectPathNode helper class.
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

#import "DKIntrospectionNode.h"

#include <dbus/dbus.h>
@class DKEndpoint, DKInterface, DKObjectPathNode, DKPort, NSMutableArray,
  NSMutableDictionary, NSString, NSXMLNode;

/**
 * The DKObjectPathNode protocol is implemented by classes representing objects
 * in a D-Bus object path (such as <code>DKProxy</code> and
 * <code>DKObjectPathNode</code>.
 */
@protocol DKObjectPathNode
/**
 * Adds the interface to the node.
 */
- (void)_addInterface: (DKInterface*)interface;
/**
 * Adds the child node to the node.
 */
- (void)_addChildNode: (id<DKObjectPathNode>)node;

/**
 * Removes a child node from the node.
 */
- (void)_removeChildNode: (id<DKObjectPathNode>)node;

/**
 * Constructs the path that the node is located in the graph.
 */
- (NSString*)_path;

/**
 * The name of the node
 */
- (NSString*)_name;

/**
 * Returns the dictionary of all interfaces supported by the node.
 */
- (NSDictionary*)_interfaces;

/**
 * Returns a dictionary of all children of the node.
 */
- (NSDictionary*)_children;
@end;


@protocol DKExportableObjectPathNode <DKObjectPathNode>

- (DBusObjectPathVTable)vTable;

- (DBusHandlerResult)handleDBusMessage: (DBusMessage*)message;

- (DKProxy*)proxyParent;
@end

/**
 * DKObjectPathNode is a lightweight class to represent child nodes in a D-Bus
 * object graph. Full DKProxy instances can be obtained with the -proxy method.
 */
@interface DKObjectPathNode: DKIntrospectionNode <DKExportableObjectPathNode>
{
  /** Contains all nodes descending from the present one. */
  NSMutableDictionary *children;
  /** Contains all interfaces supported by the present node. */
  NSMutableDictionary *interfaces;
}

/**
 * Returns a proxy representing the object specified by this node.
 */
- (DKProxy*)proxy;

- (NSXMLNode*)XMLNodeIncludingCompleteIntrospection: (BOOL)includeIntrospection
                                           absolute: (BOOL)absolutePath;

- (NSXMLNode*)XMLNodeIncludingCompleteIntrospection: (BOOL)includeIntrospection
                                        forChildren: (BOOL)includeChildIntrospection
                                           absolute: (BOOL)absolutePath;
@end


/**
 * Intermediary object that can be replaced with a real proxy when needed.
 */
@interface DKProxyStandin: DKIntrospectionNode
{
  DKEndpoint *endpoint;
  NSString *service;
  NSString *path;
}

- (id)initWithEndpoint: (DKEndpoint*)endpoint
               service: (NSString*)aService
                  path: (NSString*)aPath;

- (DKProxy*)proxy;
@end

/**
 * Object path node that can be used as the root of an object graph exported
 * through an DKPort.
 */
@interface DKRootObjectPathNode : DKObjectPathNode

- (id)initWithPort: (DKPort*)port;

- (DKPort *)_port;
@end
