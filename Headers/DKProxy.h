/** Interface for the DKProxy class representing D-Bus objects on the
    GNUstep side.
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

#import <Foundation/NSProxy.h>

@class DKEndpoint, DKInterface, NSConditionLock, NSString, NSMapTable, NSMutableArray, NSMutableDictionary;
@protocol NSCoding;

@interface DKProxy: NSProxy <NSCoding>
{
  DKEndpoint *endpoint;
  NSString *service;
  NSString *path;
  NSMapTable *selectorToMethodMap;
  NSMutableDictionary *interfaces;
  NSMutableArray *children;
  DKInterface *activeInterface;
  NSConditionLock *tableLock;
}

+ (id) proxyWithEndpoint: (DKEndpoint*)anEndpoint
              andService: (NSString*)aService
                 andPath: (NSString*)aPath;

- (id) initWithEndpoint: (DKEndpoint*)anEndpoint
             andService: (NSString*)aService
                andPath: (NSString*)aPath;

/**
 * Checks whether the to proxies are attached to the same D-Bus service.
 */
- (BOOL) hasSameScopeAs: (DKProxy*)aProxy;

/**
 * D-Bus allows identically named methods to appear in multiple interfaces. By
 * default and in accordance with the D-Bus specification, DKProxy will call the
 * first available implementation unless you specify the interface. If you
 * usually call methods from a specific interface, you can designate the
 * interface as the primary one by calling -setPrimaryDBusInterface:.
 */
- (void)setPrimaryDBusInterface: (NSString*)anInteface;
@end
