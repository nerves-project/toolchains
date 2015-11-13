#!/usr/bin/env python

# This script turns the absolute paths in an Erlang installation into
# relative ones so that Erlang can be installed anywhere the user wants.
#
# IMPORTANT: This is not a generic script. I will only work against the
#            scripts for which it was designed in an Erlang install directory.

import re
import sys
import os
import os.path

basedir = os.path.abspath(sys.argv[1])
scriptfile = os.path.abspath(sys.argv[2])
scriptdir = os.path.dirname(scriptfile)
tmpfile = scriptfile + '.out'

# Script for resolving the path to scriptfile at call-time
# See http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# (readlink -f doesn't work on Mac or this would be substantially simpler)
script="""#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
"""

# Search for directories under this base directory
dirpattern = basedir + '[/a-zA-Z0-9-]+'

with open(scriptfile, 'r') as f:
    with open(tmpfile, 'w') as g:
	# replace shebang with the script to determine source directory
	f.readline()
	g.write(script)
        for line in f:
            m = re.search(dirpattern, line)
            if m:
                # Assume one absolute to relative conversion per line
                relpath = os.path.relpath(m.group(0), scriptdir)
                line = line.replace(m.group(0), "${DIR}/" + relpath)
            g.write(line)

st = os.stat(scriptfile)
os.chmod(tmpfile, st.st_mode)
os.unlink(scriptfile)
os.rename(tmpfile, scriptfile)
