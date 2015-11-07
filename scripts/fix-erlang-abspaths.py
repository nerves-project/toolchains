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

# Search for directories under this base directory
dirpattern = basedir + '[/a-zA-Z0-9-]+'

with open(scriptfile, 'r') as f:
    with open(tmpfile, 'w') as g:
        for line in f:
            m = re.search(dirpattern, line)
            if m:
                # Assume one absolute to relative conversion per line
                relpath = os.path.relpath(m.group(0), scriptdir)
                line = line.replace(m.group(0), "$(dirname $(readlink -f $0))/" + relpath)
            g.write(line)

st = os.stat(scriptfile)
os.chmod(tmpfile, st.st_mode)
os.unlink(scriptfile)
os.rename(tmpfile, scriptfile)
