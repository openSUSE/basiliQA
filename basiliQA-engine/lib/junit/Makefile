# If we decide to use Qt5, we need to use
#   -I/usr/include/qt5
# and
#   -lQt5Xml -lQt5Core 
# instead.

QT_INC  = $(shell pkg-config QtCore --cflags)
QT_LIBS = $(shell pkg-config QtXml --libs) $(shell pkg-config QtCore --libs)

ifdef RPM_OPT_FLAGS
CCOPT	= $(RPM_OPT_FLAGS)
else
CCOPT	= -Wall -O2 -g
endif

CXXFLAGS = $(CCOPT) $(QT_INC)
LDLIBS	= $(QT_LIBS)

OBJS	= main.o to_junit.o decomposition.o

all: to_junit

to_junit: $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJS) $(LDLIBS)

install: to_junit
	mkdir -p $(DESTDIR)/usr/lib/basiliqa/lib/
	cp to_junit $(DESTDIR)/usr/lib/basiliqa/lib/

main.o: main.cpp to_junit.h decomposition.h
to_junit.o: to_junit.cpp to_junit.h decomposition.h
decomposition.o: decomposition.cpp to_junit.h decomposition.h

clean:
	rm -f to_junit
