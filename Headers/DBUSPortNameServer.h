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

   <title>DBUSPortNameServer class reference</title>
*/

#ifndef _DBUSPortNameServer_H_
#define _DBUSPortNameServer_H_

#import <Foundation/NSPortNameServer.h>

@class NSPort;
@class NSString;

@interface DBUSPortNameServer : NSMessagePortNameServer

- (NSPort *) portForName: (NSString *)name;
- (BOOL) registerPort: (NSPort *)port forName: (NSString *)name;

@end

#endif // _DBUSPortNameServer_H_
