all: helloworld

helloworld: helloworld.c
	gcc -o helloworld helloworld.c

install: helloworld
	mkdir -p ${DESTDIR}/usr/bin
	cp helloworld ${DESTDIR}/usr/bin/

clean:
	rm -f helloworld

all-tests:
	make -C testsuite-control all

install-tests:
	make -C testsuite-control install
