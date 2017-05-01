DEST=$(DESTDIR)/usr/lib/basiliqa/create-testsuite/templates/python-subpackages

.PHONY: all install

all:

install: header.py node1.py middle1.py node2.py middle2.py node3.py footer.py \
         test.sh
	mkdir -p $(DEST)
	cp *.py *.sh $(DEST)/
