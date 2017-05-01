.PHONY: all install clean

testenv: testenv.c ../common.c ../common.h
	gcc testenv.c ../common.c -o testenv -l xml2

all: testenv

install: testenv
	mkdir -p $(DESTDIR)$(BINDIR)
	cp testenv $(DESTDIR)$(BINDIR)/

clean:
	rm -f testenv

