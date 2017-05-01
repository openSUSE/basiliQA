DEST=$(DESTDIR)/usr/lib/basiliqa/static

all:

install: testenv.xslt run-tests-in-static-environment.sh \
         do-tests-in-static-environment.sh basiliqa-static.sh \
         prepare-sut.sh id_rsa.pub
	mkdir -p $(DEST)
	cp *.xslt *.pub $(DEST)/
	cp run-tests-in-static-environment.sh do-tests-in-static-environment.sh prepare-sut.sh $(DEST)/
	mkdir -p $(DESTDIR)/usr/bin
	cp basiliqa-static.sh $(DESTDIR)/usr/bin/

clean:
