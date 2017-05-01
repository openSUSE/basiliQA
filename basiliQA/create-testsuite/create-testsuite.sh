#! /bin/bash
#
# create-testsuite.sh
# Create an empty test suite based on a configuration file

# Copyright (C) 2015,2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

function usage
{
  echo "Usage:"
  echo "  $0 [ <configuration file name> ]"
  echo "  Creates an empty test suite for basiliQA based on a configuration file."
  echo
  echo "The configuration file has contents like:"
  grep -v "#" "$scripts/create-testsuite.conf" | grep -v "^$" 
  echo
  echo "By default, configuration file is named 'create-testsuite.conf'"
  echo "and is located in current directory."
}

function check-variable
{
  name="$1"
  eval "value=\$$name"

  if [ -z "$value" ]; then
    echo "Please define \$$name" >&2
    exit 1
  fi
}

function append-template
{
  sed "s/@@TYPE@@/$TYPE/g;
       s/@@PROGRAM@@/$PROGRAM/g;
       s/@@SUMMARY@@/$SUMMARY/g;
       s/@@VERSION@@/$VERSION/g;
       s/@@PACKAGER@@/$PACKAGER/g;
       s/@@EMAIL@@/$EMAIL/g;
       s/@@SUSETEST@@/$SUSETEST/g;
       s/@@TESTLIB@@/$TESTLIB/g;
       s/@@RUN@@/$RUN/g;
       s/@@NODESLIST@@/$NODESLIST/g;
       s/@@NODESLIST2@@/$NODESLIST2/g;
       s/@@PACKAGESLIST@@/$PACKAGESLIST/g;
       s/@@DATE@@/$(LANG=C date -u +"%a %b %d %T %Z %Y")/g;
       s/@@DATE2@@/$(LANG=C date -u +"%F %T %Z")/g;
       s/@@YEAR@@/$(LANG=C date -u +"%Y")/g;
       s/@@NODE@@/$node/g;
       s/@@NODE_UP@@/${node^^}/g" "$scripts/templates/$1" >> "$2"
}

function append-spec-template
{
  append-template "spec/$1.spec" "$PROJECT.spec"
}

function append-bash-template
{
  append-template "$1/$2.sh" "$PROJECT-$VERSION/testsuite-control/run.sh"
}

function append-python-template
{
  append-template "$1/$2.py" "$PROJECT-$VERSION/testsuite-control/run.py"
}

##############################################################################

# Display help if requested
scripts=$(dirname "$0")
if [ $# -gt 1 ]; then
  echo "Too many options" >&2
  usage >&2
  exit 1
fi
case "$1" in
  --help|-h)
    usage
    exit 0
    ;;
  -*)
    echo "Invalid option" >&2
    usage >&2
    exit 1
    ;;
esac

# Give an opportunity to edit configuration file
conf="$1"
[ -z "$conf" ] && conf="create-testsuite.conf"
if [ ! -f "$conf" ]; then
  cp $scripts/create-testsuite.conf "$conf"
fi
editor="$EDITOR"
[ "$editor" = "" ] && editor="vi"
$editor "$conf"

# Read configuration file
source "$conf"
for v in "TYPE" "PROGRAM" "VERSION" "PACKAGER" "EMAIL" \
         "LANGUAGE" "SUT_SUBPACKAGES" "FATAL_ERRORS" "NODES"; do
  check-variable $v
done

# Derive other variables
PROJECT="$TYPE-$PROGRAM"
case $LANGUAGE in
  bash) RUN="run.sh"
        SUSETEST=""
        TESTLIB="Requires:       basiliqa-testlib"
        ;;
  python) RUN="run.py"
          SUSETEST=" susetest-python"
          TESTLIB=""
          ;;
  *) echo '$LANGUAGE should be either "bash" or "python"' >&2
     exit 1
esac
NODESLIST=$(echo $NODES | sed 's/ /, /g')
NODESLIST2=$(echo $NODES | sed 's/\w*/"&"/g; s/ /, /g')
PACKAGESLIST="\"$TYPE-$PROGRAM\", \"$TYPE-$PROGRAM-tests-control\""
if [ "$SUT_SUBPACKAGES" = "true" ]; then
  for node in $NODES; do
    PACKAGESLIST="$PACKAGESLIST, \"$TYPE-$PROGRAM-tests-$node\""
  done
fi

# Create spec file
if [ -f "$PROJECT.spec" ]; then
  echo "File $PROJECT.spec already exists." >&2
  echo "If this is what you want, please remove it and restart." >&2
  exit 2
fi
echo "Creating $PROJECT.spec"
append-spec-template "header"
if [ "$SUT_SUBPACKAGES" = "true" ]; then
  for node in $NODES; do
    append-spec-template "package"
  done
fi
append-spec-template "build"
if [ "$SUT_SUBPACKAGES" = "true" ]; then
  for node in $NODES; do
    append-spec-template "files"
  done
fi
append-spec-template "footer"

# Create changes file
if [ -f "$PROJECT.changes" ]; then
  echo "File $PROJECT.changes already exists." >&2
  echo "If this is what you want, please remove it and restart." >&2
  exit 2
fi
echo "Creating $PROJECT.changes"
append-template "txt/changes.txt" "$PROJECT.changes"

# Create project directory tree
if [ -d "$PROJECT-$VERSION" ]; then
  echo "Directory $PROJECT-$VERSION already exists." >&2
  echo "If this is what you want, please remove it and restart." >&2
  exit 2
fi
echo "Creating $PROJECT-$VERSION"
mkdir "$PROJECT-$VERSION"
mkdir "$PROJECT-$VERSION/testsuite-control"
if [ "$SUT_SUBPACKAGES" = "true" ]; then
  for node in $NODES; do
    mkdir "$PROJECT-$VERSION/testsuite-$node"
  done
fi

# Create README
append-template "txt/readme.txt" "$PROJECT-$VERSION/README"

# Create Makefile's
append-template "make/rootdir.make" "$PROJECT-$VERSION/Makefile"
if [ "$SUT_SUBPACKAGES" = "true" ]; then
  for node in $NODES; do
    echo -e "\tmake -C testsuite-$node install" >> "$PROJECT-$VERSION/Makefile"
  done
fi
append-template "make/control.make" "$PROJECT-$VERSION/testsuite-control/Makefile"
if [ "$SUT_SUBPACKAGES" = "true" ]; then
  for node in $NODES; do
    append-template "make/node.make" "$PROJECT-$VERSION/testsuite-$node/Makefile"
  done
fi

# Create nodes file
for node in $NODES; do
  if [ "$SUT_SUBPACKAGES" = "true" ]; then
    append-template "txt/nodes-subpackages.txt" "$PROJECT-$VERSION/testsuite-control/nodes"
  else
    append-template "txt/nodes.txt" "$PROJECT-$VERSION/testsuite-control/nodes"
  fi
done

# Create metadata file
append-template "metadata/metadata.json" "$PROJECT-$VERSION/metadata.json"

# Create scripts - bash
if [ "$LANGUAGE" = "bash" ]; then
  dir="bash"
  if [ "$SUT_SUBPACKAGES" = "true" ]; then
    dir="$dir-subpackages"
  fi
  if [ "$FATAL_ERRORS" = "true" ]; then
    dir="$dir-fatal"
  fi
  append-bash-template "$dir" "header"
  for node in $NODES; do
    append-bash-template "$dir" "node"
  done
  append-bash-template "$dir" "footer"
  chmod +x "$PROJECT-$VERSION/testsuite-control/run.sh"
  if [ "$SUT_SUBPACKAGES" = "true" ]; then
    for node in $NODES; do
      append-template "$dir/test.sh" "$PROJECT-$VERSION/testsuite-$node/test.sh"
      chmod +x "$PROJECT-$VERSION/testsuite-$node/test.sh"
    done
  fi
fi

# Create scripts - python
if [ "$LANGUAGE" = "python" ]; then
  dir="python"
  if [ "$SUT_SUBPACKAGES" = "true" ]; then
    dir="$dir-subpackages"
  fi
  if [ "$FATAL_ERRORS" = "true" ]; then
    dir="$dir-fatal"
  fi
  append-python-template "$dir" "header"
  for node in $NODES; do
    append-python-template "$dir" "node1"
  done
  append-python-template "$dir" "middle1"
  for node in $NODES; do
    append-python-template "$dir" "node2"
  done
  append-python-template "$dir" "middle2"
  for node in $NODES; do
    append-python-template "$dir" "node3"
  done
  append-python-template "$dir" "footer"
  chmod +x "$PROJECT-$VERSION/testsuite-control/run.py"
  if [ "$SUT_SUBPACKAGES" = "true" ]; then
    for node in $NODES; do
      append-template "$dir/test.sh" "$PROJECT-$VERSION/testsuite-$node/test.sh"
      chmod +x "$PROJECT-$VERSION/testsuite-$node/test.sh"
    done
  fi
fi
