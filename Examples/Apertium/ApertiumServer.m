/* Singleton to provide the "Translate with Apertium" service.
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

#import "ApertiumController.h"
#import "ApertiumServer.h"
#import "ApertiumTranslator.h"

static ApertiumServer* sharedServer;

@implementation ApertiumServer
+ (void) initialize
{
  if (self == [ApertiumServer class])
  {
    sharedServer = [[self alloc] init];
  }
}

+ allocWithZone: (NSZone*)aZone
{
  if (nil == sharedServer)
  {
    return [super allocWithZone: aZone];
  }
  return nil;
}

+ (ApertiumServer*)sharedApertiumServer
{
  return sharedServer;
}

- (void)unscheduleShutdown
{
  if (shutdownTimer)
  {
    [shutdownTimer invalidate];
    shutdownTimer = nil;
  }
}

- (void)scheduleShutdown
{
  [self unscheduleShutdown];
  shutdownTimer = [NSTimer scheduledTimerWithTimeInterval: 60.0
                                                   target: NSApp
                                                 selector: @selector(terminate:)
                                                 userInfo: nil
                                                  repeats: NO];
}


- (id)init
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  [self scheduleShutdown];
  return self;
}

- (void)translate: (NSPasteboard *)pboard
         userData: (NSString*)userData
            error: (NSString**)error
{
  NSArray *types = [pboard types];
  NSString *source = nil;
  ApertiumTranslator *translator = [[ApertiumTranslator alloc] init];
  ApertiumController *ctrl = nil;
  NSWindow *window = nil;
  NSInteger languageSelectionState = 0;

  [self unscheduleShutdown];
  if (NO == [types containsObject: NSStringPboardType])
  {
    *error = _(@"Can only translate string types from pasteboard.");
    [self scheduleShutdown];
    return;
  }
  source = [pboard stringForType: NSStringPboardType];

  [translator setStringToTranslate: source];
  ctrl = [[ApertiumController alloc] initWithTranslator: translator];
  window = [ctrl window];

  if (nil == window)
  {
    *error = _(@"Could not create language selection panel");
    [ctrl release];
    [self scheduleShutdown];
    return;
  }
  languageSelectionState = [NSApp runModalForWindow: window];

  [ctrl release];

  if (NSRunAbortedResponse == languageSelectionState)
  {
    *error = _(@"Could not translate.");
    [self scheduleShutdown];
    return;
  }
  else
  {
    NSString *translation = nil;
    NS_DURING
    {
      translation = [translator translatedString];
    }
    NS_HANDLER
    {
      *error = [NSString stringWithFormat: @"Exception during translation: %@",
        localException];
      translation = nil;
    }
    NS_ENDHANDLER
    if (nil == translation)
    {
      if (nil == *error)
      {
	*error = _(@"Could not translate");
      }
      return;
    }
    [pboard setString: translation
              forType: NSStringPboardType];
  }
  [self scheduleShutdown];
}

- (NSUInteger) retainCount
{
  return UINT_MAX;
}

- (void) release
{
  //Ignore, it's a singleton;
}

- (id) autorelease
{
  return self;
}

- (id) retain
{
  return self;
}

@end
