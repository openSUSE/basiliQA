.PHONY: install

install: sut-functions.sh control-functions.sh
	mkdir -p $(DESTDIR)/usr/lib/basiliqa/testlib
	# control node:
	cp control-functions.sh $(DESTDIR)/usr/lib/basiliqa/testlib/
	# SUT:
	cp sut-functions.sh $(DESTDIR)/usr/lib/basiliqa/testlib/
