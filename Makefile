.PHONY: all gen

FILES := generate.sh

all: gen

gen:
	$(foreach file,$(FILES),bash "$(file)" &&) true
