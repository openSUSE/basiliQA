.PHONY: all install clean

INCDIR    ?= /usr/include
LIBDIR    ?= /usr/lib64
PYVERSION ?= 2.7

DSTDIR     = $(DESTDIR)$(LIBDIR)/python$(PYVERSION)/site-packages

testenv.so: testenvmodule.c ../common.c ../common.h
	gcc --shared -fPIC \
	  testenvmodule.c ../common.c -o testenv.so \
	  -I $(INCDIR)/python/ -l xml2 -l python$(PYVERSION)

all: testenv.so

install: testenv.so
	mkdir -p $(DSTDIR)
	cp testenv.so $(DSTDIR)/

clean:
	rm -f testenv.so
