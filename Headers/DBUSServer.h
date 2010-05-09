/* -*-objc-*-
  Distributed objects bridge for D-Bus
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Ricardo Correa <r.correa.r@gmail.com>
  Created: August 2008

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

  AutogsdocSource: DBUSMessageIterator.m
*/

#ifndef _DBUSServer_H_
#define _DBUSServer_H_

#import <Foundation/NSObject.h>

@class DBUSConnection;
@class NSString;

@interface DBUSServer : NSObject
{
  DBUSConnection *conn;
  NSString *name;
}

/**
 * Initializes a new server instance served on the conn connection.
 */
+ (id) serverWithConnection: (DBUSConnection *)conn
                       name: (NSString *)name;

/**
 * Initializes an instance to be served on the conn connection.
 */
- (id) initWithConnection: (DBUSConnection *)conn
                     name: (NSString *)name;

/**
 * Send a request to the bus to assign the given name to this connection.
 * May throw DBUSConnectionNameRequestException.
 */
- (void) requestName: (NSString *)name;

/**
 * Register a handler for messages sent to the path path. The handler will be
 * invoked with two parameters: the connection object on which the message was
 * received and the message to be processed.
 */
- (BOOL) registerCallback: (void *)callback
            forObjectPath: (NSString *)objPath;

/**
 * Returns the DBUSConnection object on which this service is served.
 */
- (DBUSConnection *) connection;

/**
 * Returns the qualified name by which this service is known.
 */
- (NSString *) name;

@end

#endif //_DBUSServer_H_
