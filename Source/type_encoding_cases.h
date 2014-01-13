/**
 *
 * Copyright (c) 2009 David Chisnall
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * type_encoding_cases.h -  expects the APPLY_TYPE macro to be defined.  This
 * macro is invoked once for every type and its Objective-C name.  Use this
 * file when implementing things like the -unsignedIntValue family of methods.
 * For this case, the macro will be invoked with unsigned int as the type and
 * unsignedInt as the name.
 */
#ifndef APPLY_TYPE
#error Define APPLY_TYPE(type, name, capitalizedName, encodingChar) before including this file
#endif
APPLY_TYPE(double, double, Double, 'd')
APPLY_TYPE(float, float, Float, 'f')
APPLY_TYPE(signed char, char, Char, 'c')
APPLY_TYPE(int, int, Int, 'i')
APPLY_TYPE(short, short, Short, 's')
APPLY_TYPE(long, long, Long, 'l')
APPLY_TYPE(long long, longLong, LongLong, 'q')
//APPLY_TYPE(__int128, int128, Int128, 't')
APPLY_TYPE(unsigned char, unsignedChar, UnsignedChar, 'C')
APPLY_TYPE(unsigned short, unsignedShort, UnsignedShort, 'S')
APPLY_TYPE(unsigned int, unsignedInt, UnsignedInt, 'I')
APPLY_TYPE(unsigned long, unsignedLong, UnsignedLong, 'L')
APPLY_TYPE(unsigned long long, unsignedLongLong, UnsignedLongLong, 'Q')
//APPLY_TYPE(unsigned __int128, unsignedInt128, UnsignedInt128, 'T')
#ifdef NON_INTEGER_TYPES
#undef NON_INTEGER_TYPES
APPLY_TYPE(_Bool, bool, Bool, 'B')
#ifndef SKIP_ID
APPLY_TYPE(id, object, Object, '@')
#endif
APPLY_TYPE(Class, class, Class, '#')
APPLY_TYPE(SEL, selector, Selector, ':')
APPLY_TYPE(char*, cString, CString, '*')
#endif
#undef APPLY_TYPE
