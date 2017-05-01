all:
	make -C suse
	make -C windows

install:
	mkdir -p $(DESTDIR)/var/cache/basiliqa
	make -C suse install
	make -C windows install

clean:
	make -C suse clean
	make -C windows clean
