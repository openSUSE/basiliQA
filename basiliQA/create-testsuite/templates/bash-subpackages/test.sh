#! /bin/bash

source /usr/lib/basiliqa/testlib/sut-functions.sh

jlogger testcase -i "@@NODE@@" -t "@@PROGRAM@@"

echo "Here is test script for @@NODE@@ node."

if [ $? -eq 0 ]; then
  jlogger success
else
  jlogger failure "Test has failed"
  exit 1
fi
