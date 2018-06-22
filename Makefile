PANDOC ?= pandoc

PACKAGE :=
VERSION := $(shell cat VERSION)

SOURCES :=

TARGETS := drylib.json

%.html: %.rst
	$(PANDOC) -o $@ -t html5 -s $<

drylib.json: tools/genjson.rb
	tools/genjson.rb > $@

genjson: drylib.json

genrst: drylib.json
	tools/genrst.rb $<

all: build

build: $(TARGETS)

check:
	@echo "not implemented"; exit 2 # TODO

dist:
	@echo "not implemented"; exit 2 # TODO

install:
	@echo "not implemented"; exit 2 # TODO

uninstall:
	@echo "not implemented"; exit 2 # TODO

clean:
	@rm -f *~ $(TARGETS)

distclean: clean

mostlyclean: clean

.PHONY: check dist install clean distclean mostlyclean
.PHONY: genrst
.SECONDARY:
.SUFFIXES:
