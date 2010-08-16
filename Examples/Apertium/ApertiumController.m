/* Controller for the language selection panel.
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
#import "ApertiumTranslator.h"
#import "ApertiumServer.h"

#import <AppKit/NSPanel.h>

@implementation ApertiumController

- (id) initWithTranslator: (ApertiumTranslator*)aTranslator
{
  if (nil == (self = [super initWithWindowNibName: @"LanguagePanel"]))
  {
    return nil;
  }
  ASSIGN(translator, aTranslator);
  return self;
}

- (IBAction)didChangeSourceLanguage: (id)sender
{
  NSString *sourceLang = [[sourceLanguageField selectedItem] representedObject];
  NSArray *targetLangs = [[ApertiumInfo sharedApertiumInfo] destinationLanguagesForSourceLanguage: sourceLang];
  if (0 == [targetLangs count])
  {
    [destinationLanguageField setEnabled: NO];
    [translateButton setEnabled: NO];
    return;
  }
  else
  {
    [destinationLanguageField setMenu: ApertiumMenuForLanguages(targetLangs)];
    [destinationLanguageField synchronizeTitleAndSelectedItem];
    [destinationLanguageField setEnabled: YES];
    [[destinationLanguageField target] performSelector: [destinationLanguageField action]
                                            withObject: destinationLanguageField];
  }
}

- (IBAction)didChangeDestinationLanguage: (id)sender
{
  if ([[ApertiumInfo sharedApertiumInfo] canTranslate: [[sourceLanguageField selectedItem] representedObject]
                                                 into: [[destinationLanguageField selectedItem] representedObject]])
  {
    [translateButton setEnabled: YES];
  }
  else
  {
    [translateButton setEnabled: NO];
  }
}

- (IBAction)translate: (id)sender
{
  [translator setSourceLanguage: [[sourceLanguageField selectedItem] representedObject]];
  [translator setDestinationLanguage: [[destinationLanguageField selectedItem] representedObject]];
  [NSApp stopModal];
}

- (IBAction)abort: (id)sender
{
  [NSApp abortModal];
}

- (void)dealloc
{
  [translator release];
  [super dealloc];
}
@end


inline NSMenu*
ApertiumMenuForLanguages(NSArray* langs)
{
  ApertiumInfo *info = [ApertiumInfo sharedApertiumInfo];
  NSMenu *menu = [[[NSMenu alloc] init] autorelease];
  NSEnumerator *langEnum = [langs objectEnumerator];
  NSString *aLang = nil;
  while (nil != (aLang = [langEnum nextObject]))
  {
    NSMenuItem *menuItem = [menu addItemWithTitle: [info localizedLanguageNameForLangKey: aLang]
                                           action: 0
                                    keyEquivalent: @""];
    [menuItem setRepresentedObject: aLang];
  }
  return menu;
}
