DEST=$(DESTDIR)/usr/lib/basiliqa/vms

all:

install: do-tests-in-vms.sh run-tests-in-vms.sh \
         test-vm.xml test-vm.xslt test-net.xml test-net.xslt \
         local.repo home.repo \
         basiliqa-vms.sh README.aarch64.txt
	mkdir -p $(DEST)
	cp do-tests-in-vms.sh run-tests-in-vms.sh $(DEST)/
	cp *.xml *.xslt $(DEST)/
	cp *.repo $(DEST)/
	cp README.aarch64.txt $(DEST)/
	mkdir -p $(DESTDIR)/usr/bin
	cp basiliqa-vms.sh $(DESTDIR)/usr/bin/

clean:
