.PHONY: all install clean

LIBDIR    ?= /usr/lib64
VERSION   ?= 0.2.4
RBVERSION ?= 2.1.0
RBDIR      = $(LIBDIR)/ruby/gems/$(RBVERSION)

testenv-$(VERSION).gem: testenv.gemspec Rakefile ext/testenv/extconf.rb \
                        ext/testenv/testenv.c ../common.c ../common.h
	cp ../common.c ext/testenv/
	cp ../common.h ext/testenv/
	gem build testenv.gemspec

all: testenv-$(VERSION).gem


install: testenv-$(VERSION).gem
	CFLAGS="-I$(DESTDIR)$(INCDIR)" LDFLAGS="-L$(DESTDIR)$(LIBDIR)" DESTDIR="" \
	  gem install --local \
	    --build-root $(DESTDIR) --install-dir $(RBDIR)/ \
	    testenv-$(VERSION).gem
	rm -f $(DESTDIR)$(RBDIR)/gems/testenv-$(VERSION)/ext/testenv/siteconf*.rb

clean:
	rm -f ext/testenv/common.c
	rm -f ext/testenv/common.h
	rm -f ruby/ext/testenv/Makefile
	rm -f ruby/ext/testenv/mkmf.log
	rm -f testenv-$(VERSION).gem
