/* Singleton to obtain available translation modes from Apertium.
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

#import "ApertiumInfo.h"

#import <DBusKit/DKPort.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <stdint.h>

static ApertiumInfo *sharedInfo;

@protocol APInfo
- (NSArray*) modes;
@end

@interface ApertiumInfo (Private)
- (BOOL)getInfo;
@end

@implementation ApertiumInfo
+ (void) initialize
{
  if (self == [ApertiumInfo class])
  {
    sharedInfo = [[self alloc] init];
  }
}

+ allocWithZone: (NSZone*)aZone
{
  if (nil == sharedInfo)
  {
    return [super allocWithZone: aZone];
  }
  return nil;
}

+ (ApertiumInfo*)sharedApertiumInfo
{
  return sharedInfo;
}

- (id) init
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  languagePairs = [NSMutableDictionary new];
  if (NO == [self getInfo])
  {
    [self release];
    return nil;
  }
  return self;
}

- (void)dealloc
{
  [languagePairs release];
  [super dealloc];
}

- (void) addLanguagePair: (NSArray*)thePair
{
  NSString *source = [thePair objectAtIndex: 0];
  NSString *destination = [thePair objectAtIndex: 1];
  NSMutableArray *destContainer = [languagePairs objectForKey: source];
  if (nil == destContainer)
  {
    destContainer = [[NSMutableArray alloc] initWithObjects: destination, nil];
    [languagePairs setObject: destContainer
                      forKey: source];
    [destContainer release];
  }
  else
  {
    [destContainer addObject: destination];
  }
}

- (void) addLanguagePairsFromArray: (NSArray*)langs
{
  NSEnumerator *langEnum = [langs objectEnumerator];
  NSString *theLang = nil;

  while (nil != (theLang = [[langEnum nextObject]
    stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]))
  {
    NSArray *thePair = [theLang componentsSeparatedByString: @"-"];
    if (2 == [thePair count])
    {
      [self addLanguagePair: thePair];
    }
    else
    {
      NSWarnMLog(@"'%@' does not seem to be a language pair, ignoring.",
        theLang);
    }
  }
}

- (BOOL) getInfo
{
  DKPort *sp = [[[DKPort alloc] initWithRemote: @"org.apertium.info"] autorelease];
  NSConnection *connection = [NSConnection connectionWithReceivePort: [DKPort port]
                                                            sendPort: sp];
  id<APInfo> infoObject = (id<APInfo>)[connection rootProxy];
  NSArray *modes = nil;
  if (infoObject == nil)
  {
    NSWarnMLog(@"Could not connect to Apertium.");
    return NO;
  }
  NS_DURING
  {
    modes = [infoObject modes];
  }
  NS_HANDLER
  {
    NSDictionary *info = [localException userInfo];
    if ([info objectForKey: @"org.freedesktop.DBus.Error.ServiceUnknown"])
    {
      NSWarnMLog(@"Apertium service not provided via D-Bus.");
    }
    else
    {
      NSWarnMLog(@"Error when contacting Apertium service: %@",
        localException);
    }
    modes = nil;
  }
  NS_ENDHANDLER
  if (0 == [modes count])
  {
    NSWarnMLog(@"No language pairs found.");
    return NO;
  }

  [self addLanguagePairsFromArray: modes];
  return YES;
}


- (NSArray*)sourceLanguages
{
  return [languagePairs allKeys];
}

- (NSArray*)destinationLanguagesForSourceLanguage: (NSString*)langCode
{
  return [[[languagePairs objectForKey: langCode] copy] autorelease];
}

- (NSString*)localizedLanguageNameForLangKey: (NSString*)key
{
  NSString *localeIdentifier = [NSLocale canonicalLanguageIdentifierFromString: key];
  NSLocale *locale = [NSLocale currentLocale];
  NSString *localizedName = nil;

  // Work around the fact that GNUstep's NSLocale does not yet implement
  // +canonicalLanguageIdentifierFromString:.
  localeIdentifier = (nil != localeIdentifier) ? localeIdentifier : key;

  localizedName = [locale displayNameForKey: NSLocaleLanguageCode
                                      value: localeIdentifier];
  return (nil != localizedName) ? localizedName : key;
}


- (BOOL) canTranslate: (NSString*)src
                 into: (NSString*)dst
{
  return [[languagePairs objectForKey: src] containsObject: dst];
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
