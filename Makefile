.PHONY: all gen

all: gen

gen:
	@for file in generate.sh generate_v7.sh ; do \
		bash "$$file" ; \
	done
