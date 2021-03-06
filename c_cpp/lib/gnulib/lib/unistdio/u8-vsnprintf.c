/* Formatted output to strings.
   Copyright (C) 1999, 2002, 2006-2007, 2009-2015 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify it
   under the terms of the GNU Lesser General Public License as published
   by the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

/* Specification.  */
#include "unistdio.h"

#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdlib.h>
#include "unistr.h"

#define VSNPRINTF u8_vsnprintf
#define VASNPRINTF u8_vasnprintf
#define FCHAR_T char
#define DCHAR_T uint8_t
#define DCHAR_CPY u8_cpy
#include "u-vsnprintf.h"
