DEST=$(DESTDIR)/usr/share/doc/packages/basiliqa

all:

install: README-first.txt FAQ.txt \
         HOWTO-firststeps.txt HOWTO-testpackage.txt HOWTO-jenkinsui.txt HOWTO-localtests.txt \
         HOWTO-statictests.txt \
	 REFERENCE-nodesfile.txt REFERENCE-variables.txt \
         REFERENCE-basiliqaquery.txt REFERENCE-basiliqavms.txt REFERENCE-basiliqastatic.txt \
         REFERENCE-junitformat.txt REFERENCE-createtestsuite.txt REFERENCE-testenv.txt REFERENCE-testlib.txt
	mkdir -p $(DEST)
	cp *.txt $(DEST)/
