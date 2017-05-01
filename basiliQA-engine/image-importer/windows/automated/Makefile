DEST=$(DESTDIR)/usr/lib/basiliqa/image-importer/windows/automated

all:

install: full-install.ps1 msys2openssh.sh setup.sh \
         README.prep.md
	mkdir -p $(DEST)
	cp *.ps1 *.sh *.md $(DEST)/

clean:
