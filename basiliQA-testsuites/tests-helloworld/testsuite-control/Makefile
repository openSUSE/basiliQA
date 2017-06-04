SUITE = ${DESTDIR}/var/lib/basiliqa/tests-helloworld

all:

install: nodes 01_helloworld.sh 02_helloworld_options.sh
	mkdir -p ${SUITE}/tests-control/bin
	cp nodes ${SUITE}/tests-control/
	cp *.sh ${SUITE}/tests-control/bin/
