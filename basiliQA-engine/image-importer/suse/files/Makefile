DEST=$(DESTDIR)/usr/lib/basiliqa/image-importer/suse/files

all:

install: ifcfg-ethX id_rsa.pub \
         openSUSE_13.2-x86_64.repo openSUSE_13.2-i386.repo \
         openSUSE_42.1-x86_64.repo \
         openSUSE_42.2-x86_64.repo \
         openSUSE_42.3-x86_64.repo \
         openSUSE_TW-x86_64.repo
	mkdir -p $(DEST)
	cp *-ethX *.pub *.repo $(DEST)/
