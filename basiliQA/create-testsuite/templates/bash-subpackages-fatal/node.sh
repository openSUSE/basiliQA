twopence_command -u testuser "$TARGET_@@NODE_UP@@" "cd $suite/tests-@@NODE@@/bin && ./test.sh"
if [ $? -ne 0 ]; then
  jlogger endsuite
  exit 1
fi

