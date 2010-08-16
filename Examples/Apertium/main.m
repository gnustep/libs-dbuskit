/* main.m for Apertium.service
 *
 * Copyright (C) 2010 Free Software Foundation, Inc.
 *
 * Written by:  Niels Grewe
 * Created:  July 2010
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ApertiumServer.h"

ApertiumServer *server;

@interface ApertiumDelegate: NSObject
@end

@implementation ApertiumDelegate
- (void)applicationDidFinishLaunching: (NSNotification*)notification
{
  [NSApp setServicesProvider: [ApertiumServer sharedApertiumServer]];
}
@end

int main (int argc, const char *argv[])
{
  NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
  ApertiumDelegate *delegate = [[ApertiumDelegate alloc] init];
  [[NSUserDefaults standardUserDefaults] setBool: YES
                                          forKey: @"GSSuppressAppIcon"];
  [NSApplication sharedApplication];
  [NSApp setDelegate: delegate];
  [arp release];
  return NSApplicationMain(argc, argv);
}
