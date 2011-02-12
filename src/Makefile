# Copyright (C) 2005-2006 Savonet team
# libfaad bindings for OCaml.
#
# by Samuel Mimram

# $Id: Makefile.in 2383 2006-04-09 16:21:04Z smimram $

OCAMLMAKEFILE = OCamlMakefile

OCAMLFIND = /usr/bin/ocamlfind
OCAMLFIND_LDCONF = 
OCAMLC = /usr/bin/ocamlc.opt
OCAMLOPT = /usr/bin/ocamlopt.opt
BEST = byte opt
OCAMLMKTOP = @OCAMLMKTOP@
OCAMLCP = 
OCAMLDEP = /usr/bin/ocamldep
OCAMLLEX = @OCAMLLEX@
OCAMLYACC = @OCAMLYACC@
OCAMLDOC = /usr/bin/ocamldoc
LATEX = @LATEX@
DVIPS = @DVIPS@
PS2PDF = @PS2PDF@
OCAMLLIBPATH = /usr/lib/ocaml

SOURCES = faad.mli faad.ml faad_stubs.c drms.c mp4atom.c mp4ff.c  mp4meta.c  \
          mp4sample.c mp4tagupdate.c mp4util.c
RESULT = faad
OCAMLDOCFLAGS = -stars
LIBINSTALL_FILES = $(wildcard *.mli *.cmi *.cma *.cmxa *.cmx *.a *.so)
LDFLAGS = 
ACLIBS =  -lfaad -lm
CLIBS = $(ACLIBS:-l%=%)
LIBDIRS = $(LDFLAGS:-L%=%)
CC = gcc
CFLAGS =  -I/home/toots/sources/svn/savonet/trunk/ocaml-faad/. -DHAVE_CONFIG_H  -Wall -DCAML_NAME_SPACE -DUSE_TAGGING -DITUNES_DRM
CPPFLAGS =  
NO_CUSTOM = yes
OCAMLFLAGS = 


all: $(BEST)

byte: byte-code-library

opt: native-code-library

native-code-library: byte-code-library

install: libinstall

uninstall: libuninstall

update: uninstall install

-include $(OCAMLMAKEFILE)
