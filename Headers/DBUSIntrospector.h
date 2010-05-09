/* -*-objc-*-
  Introspector for DBUS XML format
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Ricardo Correa <r.correa.r@gmail.com>
  Created: June 2008

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
*/

#ifndef _DBUSIntrospector_H_
#define _DBUSIntrospector_H_

#import <Foundation/NSObject.h>

@class GSXPathContext;
@class GSXMLDocument;
@class NSData;
@class NSDictionary;
@class NSInvocation;
@class NSMethodSignature;
@class NSString;

@interface DBUSIntrospector : NSObject
{
  GSXPathContext *context;
  NSDictionary *interfaces;
  BOOL cacheBuilt;
}

+ (NSString *) lowercaseFirstLetter: (NSString *) oldName;
+ (NSString *) uppercaseFirstLetter: (NSString *) oldName;
+ (id) introspectorWithData: (NSData *)theData;
+ (id) introspectorWithDBUSInfo: (GSXMLDocument *)dbusInfo;
- (id) initWithData: (NSData *)data;
- (id) initWithDBUSInfo: (GSXMLDocument *)DBUSInfo;
- (BOOL) buildMethodCache;
- (NSInvocation *) methodNamed: (NSString *)methName;
- (NSInvocation *) methodNamed: (NSString *)methName
                   inInterface: (NSString *)interface;
- (NSInvocation *) signalNamed: (NSString *)sigName;
- (NSInvocation *) signalNamed: (NSString *)sigName
                   inInterface: (NSString *)interface;

@end

#endif // _DBUSIntrospector_H_
