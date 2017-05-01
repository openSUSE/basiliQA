.PHONY: all install clean validate

all:
	make -C shell
	make -C python
	make -C ruby

install:
	make -C shell install
	make -C python install
	make -C ruby install

clean:
	make -C shell clean
	make -C python clean
	make -C ruby clean

validate:
	jing -c testenv.rng testenv.xml
