SUITE = ${DESTDIR}/var/lib/basiliqa/@@TYPE@@-@@PROGRAM@@

all:

install: nodes @@RUN@@
	mkdir -p ${SUITE}/tests-control/bin
	cp nodes ${SUITE}/tests-control/
	cp @@RUN@@ ${SUITE}/tests-control/bin/
