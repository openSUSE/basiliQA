#! /bin/bash

suite="/var/lib/basiliqa/@@TYPE@@-@@PROGRAM@@"
rc=0

source /usr/lib/basiliqa/testlib/control-functions.sh

jlogger testsuite -t "@@PROGRAM@@"

