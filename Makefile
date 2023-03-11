
all: gen
.PHONY: all

.PHONY: gen
gen:
	./generate.sh
	./generate_v7.sh