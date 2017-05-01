DEST=$(DESTDIR)/usr/lib/basiliqa/cloud

all:

install: do-tests-in-cloud.sh run-tests-in-cloud.sh \
         cloud-rc.sh cloud-setup.sh
	mkdir -p $(DEST)
	cp do-tests-in-cloud.sh run-tests-in-cloud.sh $(DEST)/
	cp cloud-rc.sh cloud-setup.sh $(DEST)/

clean:
