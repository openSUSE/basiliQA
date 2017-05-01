all:
	make -C init-jail
	make -C lib
	make -C cloud
	make -C vms
	make -C static
	make -C image-importer

install: basiliqa.conf channels.conf \
         basiliqa-query.sh
	mkdir -p $(DESTDIR)/usr/lib/basiliqa
	mkdir -p $(DESTDIR)/var/lib/basiliqa
	mkdir -p $(DESTDIR)/etc/basiliqa
	cp *.conf $(DESTDIR)/etc/basiliqa/
	mkdir -p $(DESTDIR)/usr/bin
	cp basiliqa-query.sh $(DESTDIR)/usr/bin/
	make -C init-jail install
	make -C lib install
	make -C cloud install
	make -C vms install
	make -C static install
	make -C image-importer install

clean:
	make -C init-jail clean
	make -C lib clean
	make -C cloud clean
	make -C vms clean
	make -C static clean
	make -C image-importer clean
