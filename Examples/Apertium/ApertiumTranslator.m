/* Class to access the Apertium translation system via D-Bus.
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

#import "ApertiumTranslator.h"
#import <DBusKit/DKPort.h>

#import <Foundation/NSConnection.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>


@implementation ApertiumTranslator
- (id)init
{
  DKPort *sp = [[[DKPort alloc] initWithRemote: @"org.apertium.mode"] autorelease];
  NSConnection *connection = [NSConnection connectionWithReceivePort: [DKPort port]
                                                            sendPort: sp];
  if (nil == (self = [super init]))
  {
    return nil;
  }
  translator = [[connection rootProxy] retain];

  if (nil == translator)
  {
    NSWarnMLog(@"Could not connect to Apertium");
    [self release];
    return nil;
  }
  return self;
}

- (void)dealloc
{
  [translator release];
  [sourceLanguage release];
  [destinationLanguage release];
  [options release];
  [stringToTranslate release];
  [super dealloc];
}
- (void) setOptions: (NSDictionary*)someOptions
{
  ASSIGN(options,someOptions);
}

- (NSDictionary*)options
{
  return options;
}
- (void) setStringToTranslate: (NSString*)aString
{
  ASSIGN(stringToTranslate,aString);
}
- (NSString*)stringToTranslate
{
  return stringToTranslate;
}
- (void)setSourceLanguage: (NSString*)langKey
{
  ASSIGN(sourceLanguage, langKey);
}
- (NSString*)sourceLanguage
{
  return sourceLanguage;
}
- (void)setDestinationLanguage: (NSString*)langKey
{
  ASSIGN(destinationLanguage, langKey);
}
- (NSString*)destinationLanguage
{
  return destinationLanguage;
}

- (NSString*)languagePair
{
  return [NSString stringWithFormat: @"%@-%@", sourceLanguage, destinationLanguage];
}
- (NSString*)translatedString: (NSString*)textToTranslate
                 fromLanguage: (NSString*)source
                 intoLanguage: (NSString*)destination
                 usingOptions: (NSDictionary*)someOptions
{
  [self setSourceLanguage: source];
  [self setDestinationLanguage: destination];
  [self setOptions: someOptions];
  [self setStringToTranslate: textToTranslate];
  return [self translatedString];
}

- (NSString*)translatedString
{
  return [translator translate: [self languagePair]
                              : [self options]
			      : [self stringToTranslate]];
}
@end
