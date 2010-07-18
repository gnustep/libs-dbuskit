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
#import <AppKit/AppKit.h>
#import "ApertiumInfo.h"
#import "ApertiumTranslator.h"
#import "SourceLanguagePopup.h"

@interface ApertiumController: NSWindowController
{
  IBOutlet SourceLanguagePopUp *sourceLanguageField;
  IBOutlet NSPopUpButton *destinationLanguageField;
  IBOutlet NSButton *translateButton;
  ApertiumTranslator *translator;
}
- (id)initWithTranslator: (ApertiumTranslator*)translator;
- (IBAction)translate: (id)sender;
- (IBAction)abort: (id)sender;
- (IBAction)didChangeSourceLanguage: (id)sender;
- (IBAction)didChangeDestinationLanguage: (id)sender;
@end

NSMenu* ApertiumMenuForLanguages(NSArray *languages);
