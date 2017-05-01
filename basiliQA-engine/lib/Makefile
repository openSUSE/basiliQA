all: read_nodes_file
	make -C junit

read_nodes_file: read_nodes_file.c
	gcc read_nodes_file.c -o read_nodes_file

install: basiliqa-basic-functions.sh basiliqa-functions.sh \
         read_nodes_file
	mkdir -p $(DESTDIR)/usr/lib/basiliqa/lib
	cp *.sh read_nodes_file $(DESTDIR)/usr/lib/basiliqa/lib/
	make -C junit install

clean:
	rm -f read_nodes_file
	make -C junit clean
