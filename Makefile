.PHONY: all gen

all: gen

gen:
	@for file in generate.sh ; do \
		bash "$$file" ; \
	done
