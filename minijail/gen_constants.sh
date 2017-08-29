#!/bin/sh

# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Generates a header file with a named constant table made up of "name", value
# entries by including several build target header files and emitting the list
# of defines.  Use of the preprocessor is needed to recursively include all
# relevant headers.

set -e

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
  echo "Usage: $(basename "$0") OUTFILE"
  echo "Usage: $(basename "$0") CC OUTFILE"
  exit 1
fi

if [ $# -eq 2 ]; then
  CC="$1"
  shift
fi
OUTFILE="$1"

INCLUDES='
#include <errno.h>
#include <fcntl.h>
#include <linux/prctl.h>
#include <linux/sched.h>
#include <stddef.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>'

# sed expression which extracts constants and converts them from:
#   #define AT_FDWCD foo
# to:
# #ifdef AT_FDCWD
#   { "AT_FDWCD", AT_FDCWD },
# endif
SED_MULTILINE='s@#define ([[:upper:]][[:upper:]0-9_]*).*@#ifdef \1\
  { "\1", (unsigned long) \1 },\
#endif  // \1@'

# Passes the previous list of #includes to the C preprocessor and prints out
# all #defines whose name is all-caps.  Excludes a few symbols that are known
# macro functions that don't evaluate to a constant.
cat <<-EOF > "${OUTFILE}"
/* GENERATED BY MAKEFILE */
$INCLUDES

#include "libconstants.h"
const struct constant_entry constant_table[] = {
$(echo "$INCLUDES" | \
  ${CC} -dD - -E | \
  grep -E '^#define [[:upper:]][[:upper:]0-9_]*(\s)+[[:alnum:]]' | \
  grep -Ev '(SIGRTMAX|SIGRTMIN|SIG_|NULL)' | \
  sort -u | \
  sed -Ee "${SED_MULTILINE}")
  { NULL, 0 },
};
EOF
