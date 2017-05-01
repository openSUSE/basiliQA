SUITE = ${DESTDIR}/var/lib/basiliqa/@@TYPE@@-@@PROGRAM@@

all:

install: README
	mkdir -p ${SUITE}
	cp README ${SUITE}/
	make -C testsuite-control install
