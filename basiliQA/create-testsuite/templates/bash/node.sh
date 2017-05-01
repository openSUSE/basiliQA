jlogger testcase -i "@@NODE@@" -t "@@PROGRAM@@"
twopence_command -u testuser "$TARGET_@@NODE_UP@@" "uptime"
if [ $? -eq 0 ]; then
  jlogger success
else
  jlogger failure -t "Test has failed"
  rc=1
fi

