DEST=$(DESTDIR)/usr/lib/basiliqa/create-testsuite/templates/bash-subpackages

.PHONY: all install

all:

install: header.sh node.sh footer.sh \
         test.sh
	mkdir -p $(DEST)
	cp *.sh $(DEST)/
