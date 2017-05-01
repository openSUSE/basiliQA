DEST=$(DESTDIR)/usr/lib/basiliqa/create-testsuite/templates/make

.PHONY: all install

all:

install: rootdir.make control.make node.make
	mkdir -p $(DEST)
	cp *.make $(DEST)/
