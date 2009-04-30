SOURCES = aac2wav.ml
RESULT = aac2wav
INCDIRS = ../src
LIBS = unix faad

test: all
	./aac2wav demoedit.aac test.wav

debug: all
	gdb --args ./aac2wav demoedit.aac test.wav

all: dnc

include OCamlMakefile
