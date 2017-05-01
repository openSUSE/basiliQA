DEST=$(DESTDIR)/usr/lib/basiliqa/image-importer/windows

all:
	make -C manual
	make -C automated

install: README.windows.md
	make -C manual install
	make -C automated install
	mkdir -p $(DEST)
	cp *.md $(DEST)/

clean:
	make -C manual clean
	make -C automated clean
