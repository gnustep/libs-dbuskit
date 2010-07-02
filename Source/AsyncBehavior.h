/** Header for enabling asynchronous behaviour using libtoydispatch if possible.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

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
#ifndef ASYNC_BEHAVIOR_H_INCLUDED
#define ASYNC_BEHAVIOR_H_INCLUDED

#include "config.h"

#if HAVE_TOYDISPATCH == 1

#include <toydispatch/toydispatch.h>

#define ASYNC_INIT_QUEUE(x,y) x = dispatch_queue_create(y, 0)
#define ASYNC_IF_POSSIBLE(queue, func, data) dispatch_async_f(queue, func, (void*)data)

#else

// Without toydispatch, we work synchronously
#define ASYNC_INIT_QUEUE(x,y)
#define ASYNC_IF_POSSIBLE(queue, func, data) func(data)

#endif // HAVE_TOYDISPATCH

#endif // ASYNC_BEHAVIOR_H_INCLUDED
