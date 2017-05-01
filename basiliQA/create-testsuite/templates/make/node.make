SUITE = ${DESTDIR}/var/lib/basiliqa/@@TYPE@@-@@PROGRAM@@

all:

install: test.sh
	mkdir -p ${SUITE}/tests-@@NODE@@/bin
	cp *.sh  ${SUITE}/tests-@@NODE@@/bin/
