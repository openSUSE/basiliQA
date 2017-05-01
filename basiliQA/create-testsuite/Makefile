DEST=$(DESTDIR)/usr/lib/basiliqa/create-testsuite

.PHONY: all install

all:

install: create-testsuite.conf create-testsuite.sh
	mkdir -p $(DEST)
	cp create-testsuite.* $(DEST)/
	make -C templates install
