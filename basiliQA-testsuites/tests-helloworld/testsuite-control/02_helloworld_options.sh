#! /bin/bash

rc=0

source /usr/lib/basiliqa/testlib/control-functions.sh

jlogger testsuite -t "helloworld with options"

jlogger testcase -i "helloworld.options.help" -t "Help option"
twopence_command -u testuser \
                 -o $WORKSPACE/result \
                 -t 5 \
                 "$TARGET_SUT" "helloworld --help"
if [ $? -ne 0 ]; then
  jlogger failure -t "Execution failed"
  rc=1
else
  RESULT="$(head -n 1 $WORKSPACE/result)"
  if [ "$RESULT" == "Usage:" ]; then
    jlogger success
  else
    jlogger failure -t "Expected \"Usage: ...\", got \"$RESULT\""
    rc=2
  fi
fi

jlogger testcase -i "helloworld.options.unknown" -t "Unknown options"
twopence_command -u testuser \
                 -o $WORKSPACE/result \
                 -t 5 \
                 "$TARGET_SUT" "helloworld --foo bar"
if [ $? -ne 0 ]; then
  jlogger success
else
  jlogger failure -t "Expected a failure after using wrong options, but got none"
  rc=3
fi

jlogger endsuite
exit $rc
