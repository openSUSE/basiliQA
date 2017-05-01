twopence_command -u testuser "$TARGET_@@NODE_UP@@" "cd $suite/tests-@@NODE@@/bin && ./test.sh"
[ $? -eq 0 ] || rc=1

