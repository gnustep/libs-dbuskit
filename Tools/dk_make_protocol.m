/** Small tool to generate protocol declarations from introspection data.

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: August 2010

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYING.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

   */
#import <Foundation/Foundation.h>
#import "../Source/DKProxy+Private.h"
#import "../Source/DKIntrospectionParserDelegate.h"
#import "../Source/DKInterface.h"

#include <fcntl.h>
@interface DKIntrospector: NSObject <DKObjectPathNode>
{
  NSMutableArray *nodes;
  NSMutableDictionary *interfaces;
}
@end

@implementation DKIntrospector
- (id)init
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  interfaces = [NSMutableDictionary new];
  nodes = [NSMutableArray new];
  return self;
}
- (NSString*)_path
{
  return @"/";
}

- (void)_addChildNode: (DKObjectPathNode*)node
{
  if (nil != node)
  {
    [nodes addObject: node];
  }
}

- (void)_addInterface: (DKInterface*)interface
{
  NSString *name = [interface name];
  if (nil != name)
  {
    [interfaces setObject: interface
    forKey: name];
  }
}

- (NSDictionary*)_interfaces
{
  return interfaces;
}

- (void)dealloc
{
  [interfaces release];
  [nodes release];
  [super dealloc];
}
@end
enum
{
  EXPECT_SWITCH,
  EXPECT_PATH
};

int main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSProcessInfo *info = [NSProcessInfo processInfo];
  NSArray *args = [info arguments];
  NSUInteger argCount = [args count];
  NSUInteger argIndex = 1;
  NSUInteger argState = EXPECT_SWITCH;
  BOOL useObjC2 = YES;
  NSString *inPath = nil;
  NSString *outPath = nil;
  NSString **pathAddr = NULL;
  NSURL *inURL = nil;
  NSXMLParser *parser = nil;
  DKIntrospectionParserDelegate *delegate = nil;
  DKIntrospector *spector = nil;
  NSFileHandle *outHandle = nil;
  NSDictionary *interfaces = nil;
  DKInterface *thisIf = nil;
  NSEnumerator *ifEnum = nil;

  for (argIndex = 1; argIndex < argCount; argIndex++)
  {
    NSString *thisArg = [args objectAtIndex: argIndex];
    if (([thisArg hasPrefix: @"-"]) && (EXPECT_SWITCH == argState))
    {
      if ([thisArg isEqualToString: @"-2"])
      {
	useObjC2 = YES;
	argState = EXPECT_SWITCH;
      }
      else if ([thisArg isEqualToString: @"-1"])
      {
	useObjC2 = NO;
	argState = EXPECT_SWITCH;
      }
      else if ([thisArg isEqualToString: @"-i"])
      {
	pathAddr = &inPath;
	argState = EXPECT_PATH;
      }
      else if ([thisArg isEqualToString: @"-o"])
      {
	pathAddr = &outPath;
	argState = EXPECT_PATH;
      }
    }
    else if (EXPECT_PATH == argState)
    {
      if (pathAddr != NULL)
      {
        *pathAddr = thisArg;
      }
      argState = EXPECT_SWITCH;
    }
    else
    {
      pathAddr = NULL;
    }
  }

  if ((argCount == 1) || (nil == inPath))
  {
    GSPrintf(stderr, @"Usage:\nUse '-i' to specify the input file and '-o' to specify the output file.\n'-1' specifies not to use features that require Objective-C 2.\nIf no output file is given, stdout is used.\n");
    return 1;
  }

  inURL = [NSURL fileURLWithPath: [inPath stringByStandardizingPath]];
  if (nil == inURL)
  {
    return 1;
  }

  spector = [[[DKIntrospector alloc] init] autorelease];

  delegate = [[[DKIntrospectionParserDelegate alloc] initWithParentForNodes: spector] autorelease];

  parser = [[[NSXMLParser alloc] initWithContentsOfURL: inURL] autorelease];
  [parser setDelegate: delegate];
  [parser parse];

  interfaces = [spector _interfaces];
  if (0 == [interfaces count])
  {
    GSPrintf(stderr, @"No interfaces found.\n");
    return 1;
  }

  if (outPath == nil)
  {
    outHandle = [NSFileHandle fileHandleWithStandardOutput];
  }
  else
  {
    int fd = -1;
    outPath = [outPath stringByStandardizingPath];
    fd = creat([outPath UTF8String], 0644);
    if (-1 == fd)
    {
      GSPrintf(stderr,@"Could not open '%@'.\n", outPath);
      return 1;
    }
    outHandle = [[[NSFileHandle alloc] initWithFileDescriptor: fd
                                               closeOnDealloc: NO] autorelease];
  }
  if (outHandle == nil)
  {
    GSPrintf(stderr, @"Could write data.\n");
    return 1;
  }

  ifEnum = [interfaces objectEnumerator];
  while (nil != (thisIf = [ifEnum nextObject]))
  {
    NSString *preamble = [NSString stringWithFormat: @"#import <Foundation/Foundation.h>\n\n/*\n * Objective-C protocol declaration for the D-Bus %@ interface.\n */\n",
      [thisIf name]];
    [outHandle writeData: [preamble dataUsingEncoding: NSUTF8StringEncoding
                                 allowLossyConversion: YES]];
    [outHandle writeData: [[thisIf protocolDeclarationForObjC2: useObjC2] dataUsingEncoding: NSUTF8StringEncoding
                                                     allowLossyConversion: YES]];
  }
  [outHandle closeFile];
  [pool release];
  return 0;
}
