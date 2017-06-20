DEST=$(DESTDIR)/usr/lib/basiliqa/image-importer/suse/iso

all:

install: autoinst-opensuse-13.2.xml \
         autoinst-opensuse-42.1.xml autoinst-opensuse-42.2.xml autoinst-opensuse-42.3.xml \
         autoinst-opensuse-tw.xml \
         autoinst.xslt basebox.xml basebox.xslt \
         keypresses-aarch64.exp keypresses-i586.exp keypresses-x86_64.exp \
         keypresses-ppc64.exp keypresses-ppc64le.exp \
         keypresses-s390x.exp keypresses-s390x-stage2.exp \
         iso2qcow2.sh do-i2q-A.sh do-i2q-B.sh do-i2q-C.sh
	mkdir -p $(DEST)
	cp *.sh *.xml *.xslt *.exp $(DEST)/

clean:
