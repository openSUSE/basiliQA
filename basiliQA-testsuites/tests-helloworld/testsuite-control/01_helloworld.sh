#! /bin/bash

rc=0

source /usr/lib/basiliqa/testlib/control-functions.sh

jlogger testsuite -t "helloworld"

jlogger testcase -i "helloworld.helloworld" -t "helloworld"
twopence_command -u testuser \
                 -o $WORKSPACE/result \
                 -t 5 \
                 "$TARGET_SUT" "helloworld"
if [ $? -ne 0 ]; then
  jlogger failure -t "Execution failed"
  rc=1
else
  RESULT="$(< $WORKSPACE/result)"
  if [ "$RESULT" == "Hello, World!" ]; then
    jlogger success
  else
    jlogger failure -t "Expected \"Hello, World!\", got \"$RESULT\""
    rc=2
  fi
fi

jlogger endsuite
exit $rc
