DEST=$(DESTDIR)/usr/lib/basiliqa/create-testsuite/templates

.PHONY: all install

all:

install:
	make -C spec install
	make -C txt install
	make -C make install
	make -C metadata install
	make -C bash install
	make -C bash-subpackages install
	make -C bash-fatal install
	make -C bash-subpackages-fatal install
	make -C python install
	make -C python-subpackages install
	make -C python-fatal install
	make -C python-subpackages-fatal install
