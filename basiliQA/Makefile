.PHONY: all install clean

all:
	make -C testenv

install: LICENSE
	mkdir -p $(DESTDIR)/var/lib/basiliqa
	mkdir -p $(DESTDIR)/usr/share/doc/packages/basiliqa
	cp LICENSE $(DESTDIR)/usr/share/doc/packages/basiliqa/LICENSE.txt
	make -C testenv install
	make -C testlib install
	make -C create-testsuite install
	make -C doc install

clean:
	make -C testenv clean
