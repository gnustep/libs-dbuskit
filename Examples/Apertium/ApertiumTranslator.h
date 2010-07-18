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
#import <Foundation/NSObject.h>

@class NSDictionary, NSString;

@protocol APTranslator
- (NSString*)translate: (NSString*)pair : (NSDictionary*)options : (NSString*)textToTranslate;
- (NSString*)translate: (NSDictionary*)options : (NSString*)textToTranslate;
@end

@interface ApertiumTranslator: NSObject
{
  id<NSObject,APTranslator> translator;
  NSString *sourceLanguage;
  NSString *destinationLanguage;
  NSString *stringToTranslate;
  NSDictionary *options;
}
- (void) setOptions: (NSDictionary*)options;
- (NSDictionary*)options;
- (void) setStringToTranslate: (NSString*)aString;
- (NSString*)stringToTranslate;

- (void)setSourceLanguage: (NSString*)langKey;
- (NSString*)sourceLanguage;
- (void)setDestinationLanguage: (NSString*)langKey;
- (NSString*)destinationLanguage;
- (NSString*)translatedString;
- (NSString*)translatedString: (NSString*)textToTranslate
                 fromLanguage: (NSString*)source
                 intoLanguage: (NSString*)destination
                 usingOptions: (NSDictionary*)options;

@end
