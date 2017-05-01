DEST=$(DESTDIR)/usr/lib/basiliqa/create-testsuite/templates/spec

.PHONY: all install

all:

install: header.spec package.spec build.spec files.spec footer.spec
	mkdir -p $(DEST)
	cp *.spec $(DEST)/
