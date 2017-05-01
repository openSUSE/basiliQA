jlogger testcase -i "@@NODE@@" -t "@@PROGRAM@@"
twopence_command -u testuser "$TARGET_@@NODE_UP@@" "uptime"
if [ $? -eq 0 ]; then
  jlogger success
else
  jlogger failure "Test has failed"
  jlogger endsuite
  exit 1
fi

