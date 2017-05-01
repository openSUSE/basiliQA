DEST=$(DESTDIR)/usr/lib/basiliqa/init-jail

all:

install: etc_group etc_os_release etc_passwd etc_sudoers \
         bashrc ssh_id_rsa init-jail.sh
	mkdir -p $(DEST)
	cp etc_* $(DEST)/
	cp bashrc ssh_id_rsa init-jail.sh $(DEST)/

clean:
