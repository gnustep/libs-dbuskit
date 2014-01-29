/** Common macro declarations for DBusKit
   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2014

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */


/*
 * The deprecated attribute for methods is supported by clang
 * and by GCC 4.6 or later.
 */
#ifndef DK_METHOD_DEPRECATED
#  ifdef __clang__
#    define DK_METHOD_DEPRECATED __attribute__((deprecated))
#  elif (__GNUC__ > 4) \
    || (__GNUC__ == 4 && (( __GNUC_MINOR__ > 6) \
                        || (__GNUC_MINOR__ == 6)))
#    define DK_METHOD_DEPRECATED __attribute__((deprecated))
#  else     
#    define DK_METHOD_DEPRECATED 
#  endif
#endif
