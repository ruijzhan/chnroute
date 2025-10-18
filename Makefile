.PHONY: all analyze benchmark check check-deps clean ci-test dev-setup fast \
	 generate help info install memory-profile package test uninstall \
	 validate validate-output validate-syntax service-setup

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

SCRIPT := generate.sh
GFW_SCRIPT := gfwlist2dnsmasq.sh
VERSION := $(shell awk -F'"' '/^readonly SCRIPT_VERSION/ {print $$2}' lib/config.sh 2>/dev/null | head -n1 || echo unknown)

OUTPUT_FILES := CN.rsc CN_mem.rsc gfwlist_v7.rsc gfwlist.txt 03-gfwlist.conf

INSTALL_DIR := /opt/chnroute
CONFIG_DIR := /etc/chnroute
SERVICE_DIR := /etc/systemd/system

COLOR_RESET := \033[0m
COLOR_GREEN := \033[0;32m
COLOR_RED := \033[0;31m
COLOR_YELLOW := \033[1;33m
COLOR_BLUE := \033[0;34m
COLOR_CYAN := \033[0;36m
COLOR_BOLD := \033[1m

define log
	printf '%b[%s]%b %s\n' "$(COLOR_BLUE)" "$$(date '+%H:%M:%S')" "$(COLOR_RESET)" "$(1)"
endef

define log_success
	printf '%b[OK]%b %s\n' "$(COLOR_GREEN)" "$(COLOR_RESET)" "$(1)"
endef

define log_error
	printf '%b[ERROR]%b %s\n' "$(COLOR_RED)" "$(COLOR_RESET)" "$(1)"
endef

define log_warn
	printf '%b[WARN]%b %s\n' "$(COLOR_YELLOW)" "$(COLOR_RESET)" "$(1)"
endef

define log_info
	printf '%b[INFO]%b %s\n' "$(COLOR_CYAN)" "$(COLOR_RESET)" "$(1)"
endef

all: generate validate-output

help:
	@printf '%bChina Route Generator v%s%b\n' "$(COLOR_BOLD)" "$(VERSION)" "$(COLOR_RESET)"
	@printf '%b==============================%b\n' "$(COLOR_BOLD)" "$(COLOR_RESET)"
	@printf '\nUsage: make [target]\n\n'
	@printf '%bBasic Targets:%b\n' "$(COLOR_BLUE)" "$(COLOR_RESET)"
	@printf '  generate         Generate China route rules (default)\n'
	@printf '  fast             Run generation without dependency checks\n'
	@printf '  clean            Remove temporary files\n'
	@printf '  check            Verify dependencies and shell syntax\n'
	@printf '  validate         Validate generated output files\n'
	@printf '  test             Run generation and output checks\n\n'
	@printf '%bDevelopment Targets:%b\n' "$(COLOR_BLUE)" "$(COLOR_RESET)"
	@printf '  benchmark        Measure generation performance\n'
	@printf '  memory-profile   Gather basic memory usage information\n'
	@printf '  analyze          Summarize output file sizes and line counts\n'
	@printf '  dev-setup        Create helper aliases and shell completion\n'
	@printf '  ci-test          Run an extended local CI flow\n\n'
	@printf '%bSystem Targets:%b\n' "$(COLOR_BLUE)" "$(COLOR_RESET)"
	@printf '  install          Install scripts and data to the system (root)\n'
	@printf '  uninstall        Remove installed files and services (root)\n'
	@printf '  service-setup    Provision a systemd timer for daily updates (root)\n'
	@printf '  package          Create a distributable archive under dist/\n\n'
	@printf '%bExamples:%b\n' "$(COLOR_BLUE)" "$(COLOR_RESET)"
	@printf '  make                   # generate and validate outputs\n'
	@printf '  make clean generate    # clean and regenerate\n'
	@printf '  make benchmark         # run performance benchmark\n'
	@printf '  sudo make install      # install system-wide\n'

check-deps:
	@$(call log,Checking dependencies...)
	@missing=0; \
	for cmd in bash curl awk sort base64 grep sed tar; do \
		if ! command -v $$cmd >/dev/null 2>&1; then \
			$(call log_error,Command "$$cmd" is required but not found); \
			missing=$$((missing + 1)); \
		fi; \
	done; \
	if [ ! -x /usr/bin/time ]; then \
		$(call log_warn,/usr/bin/time not available -- detailed timing output reduced); \
	fi; \
	if ! command -v python3 >/dev/null 2>&1; then \
		$(call log_warn,python3 not found -- benchmarks will skip average calculation); \
	fi; \
	if ! command -v shellcheck >/dev/null 2>&1; then \
		$(call log_warn,shellcheck not available -- static analysis skipped); \
	fi; \
	if [ $$missing -gt 0 ]; then \
		$(call log_error,$$missing required commands are missing); \
		exit 1; \
	fi
	@$(call log_success,All mandatory dependencies are available)

validate-syntax:
	@$(call log,Validating script syntax...)
	@bash -n "$(SCRIPT)" >/dev/null
	@bash -n "$(GFW_SCRIPT)" >/dev/null
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck *.sh || $(call log_warn,ShellCheck reported issues); \
	else \
		$(call log_warn,shellcheck not installed -- skipping lint); \
	fi
	@$(call log_success,Syntax validation completed)

check: check-deps validate-syntax

generate: check
	@$(call log,Generating China route artifacts...)
	@if bash "$(SCRIPT)"; then \
		$(call log_success,Generation completed); \
	else \
		$(call log_error,Generation failed); \
		exit 1; \
	fi

fast:
	@$(call log,Fast generation mode -- dependency checks skipped)
	@if bash "$(SCRIPT)"; then \
		$(call log_success,Fast generation completed); \
	else \
		$(call log_error,Fast generation failed); \
		exit 1; \
	fi

validate-output:
	@$(call log,Validating output files...)
	@missing=0; \
	for file in $(OUTPUT_FILES); do \
		if [ -f "$$file" ]; then \
			size=$$(wc -c < "$$file"); \
			lines=$$(wc -l < "$$file"); \
			printf '  %s: %s lines, %s bytes\n' "$$file" "$$lines" "$$size"; \
			if [ "$$size" -eq 0 ]; then \
				$(call log_warn,$$file is empty); \
				missing=$$((missing + 1)); \
			fi; \
		else \
			$(call log_error,$$file not found); \
			missing=$$((missing + 1)); \
		fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
		$(call log_error,Output validation failed); \
		exit 1; \
	fi
	@$(call log_success,All output files look good)

validate: validate-output

clean:
	@$(call log,Removing temporary files...)
	@rm -rf logs/ *.tmp *.processed chnroute_* .make.d
	@find . -name '*.log' -delete 2>/dev/null || true
	@find . -name 'gfwlist_autoproxy.txt' -delete 2>/dev/null || true
	@find . -name '*.bak' -delete 2>/dev/null || true
	@$(call log_success,Cleanup completed)

test: generate validate-output
	@$(call log,Running comprehensive checks...)
	@for file in $(OUTPUT_FILES); do \
		if [ -f "$$file" ]; then \
			lines=$$(wc -l < "$$file"); \
			size=$$(wc -c < "$$file"); \
			printf '  %s: %s lines, %s bytes\n' "$$file" "$$lines" "$$size"; \
		fi; \
	done
	@$(call log_success,Comprehensive checks passed)

benchmark:
	@$(call log,Running performance benchmark...)
	@if [ -x /usr/bin/time ]; then \
		echo '  Cold cache run:'; \
		/usr/bin/time -f '    real %E  user %U  sys %S' bash "$(SCRIPT)" >/dev/null; \
		echo '  Warm cache run:'; \
		/usr/bin/time -f '    real %E  user %U  sys %S' bash "$(SCRIPT)" >/dev/null; \
	else \
		$(call log_warn,/usr/bin/time not available -- using shell built-in timing); \
		echo '  Cold cache run:'; \
		time -p bash "$(SCRIPT)" >/dev/null; \
		echo '  Warm cache run:'; \
		time -p bash "$(SCRIPT)" >/dev/null; \
	fi
	@if command -v python3 >/dev/null 2>&1; then \
		echo '  Average of 3 runs:'; \
		SCRIPT_PATH="$(SCRIPT)" python3 - <<-'PY'; \
	import os
	import subprocess
	import sys
	import time

	script = os.environ.get("SCRIPT_PATH")
	if not script:
	    sys.exit("SCRIPT_PATH is not set")

	durations = []
	for idx in range(1, 4):
	    start = time.perf_counter()
	    subprocess.run(["bash", script], check=True, stdout=subprocess.DEVNULL)
	    duration = time.perf_counter() - start
	    durations.append(duration)
	    print(f"    Run {idx}: {duration:.3f} s")

	avg = sum(durations) / len(durations)
	print(f"  Average: {avg:.3f} s")
	PY
	else \
		$(call log_warn,python3 not found -- skipping averaged timing); \
	fi
	@$(call log_success,Benchmark completed)

analyze:
	@$(call log,Analyzing output files...)
	@total_size=0; \
	total_lines=0; \
	for file in $(OUTPUT_FILES); do \
		if [ -f "$$file" ]; then \
			size=$$(wc -c < "$$file"); \
			lines=$$(wc -l < "$$file"); \
			printf '  %s: %s lines, %s bytes\n' "$$file" "$$lines" "$$size"; \
			total_size=$$((total_size + size)); \
			total_lines=$$((total_lines + lines)); \
		fi; \
	done; \
	printf '  Totals: %s lines, %s bytes\n' "$$total_lines" "$$total_size"

memory-profile:
	@$(call log,Collecting memory profile...)
	@if command -v /usr/bin/time >/dev/null 2>&1; then \
		/usr/bin/time -v bash "$(SCRIPT)" >/dev/null 2>&1 | grep -E 'Maximum resident set size|User time|System time|Percent of CPU' || true; \
	else \
		$(call log_warn,/usr/bin/time not available -- skipping memory profile); \
	fi

dev-setup:
	@$(call log,Setting up development helpers...)
	@mkdir -p .make.d
	@cat <<-'EOF' > .make.d/aliases
	alias cn-gen='make generate'
	alias cn-fast='make fast'
	alias cn-clean='make clean'
	alias cn-test='make test'
	alias cn-bench='make benchmark'
	alias cn-analyze='make analyze'
	EOF
	@cat <<-'EOF' > .make.d/completion.bash
	_chnroute_completion() {
	    local cur words
	    COMPREPLY=()
	    cur="${COMP_WORDS[COMP_CWORD]}"
	    words="generate fast clean check validate test benchmark analyze dev-setup help"
	    COMPREPLY=( $(compgen -W "${words}" -- "${cur}") )
	    return 0
	}
	complete -F _chnroute_completion make
	EOF
	@cat <<-'EOF' > .make.d/setup.sh
	#!/usr/bin/env bash
	if [ -f "$(CURDIR)/.make.d/aliases" ]; then
	    # shellcheck disable=SC1091
	    . "$(CURDIR)/.make.d/aliases"
	fi
	if [ -f "$(CURDIR)/.make.d/completion.bash" ]; then
	    # shellcheck disable=SC1091
	    . "$(CURDIR)/.make.d/completion.bash"
	fi
	echo 'chnroute development helpers loaded'
	EOF
	@chmod +x .make.d/setup.sh
	@$(call log_success,Development helpers ready)
	@$(call log_info,Run 'source .make.d/setup.sh' to enable aliases for the current shell)

ci-test:
	@$(call log,Running local CI workflow...)
	@$(MAKE) clean
	@$(MAKE) check
	@$(MAKE) test
	@$(MAKE) benchmark
	@$(MAKE) analyze
	@$(call log_success,CI workflow completed)

install: generate validate-output
	@$(call log,Installing chnroute to $(INSTALL_DIR)...)
	@if [ "$$EUID" -ne 0 ]; then \
		$(call log_error,Installation requires root privileges); \
		echo 'Run with: sudo make install'; \
		exit 1; \
	fi
	@mkdir -p "$(INSTALL_DIR)" "$(CONFIG_DIR)"
	@for file in $(OUTPUT_FILES); do cp "$$file" "$(INSTALL_DIR)/"; done
	@cp "$(SCRIPT)" "$(GFW_SCRIPT)" "$(INSTALL_DIR)/"
	@cp include_list.txt "$(CONFIG_DIR)/" 2>/dev/null || true
	@cp exclude_list.txt "$(CONFIG_DIR)/" 2>/dev/null || true
	@chmod 755 "$(INSTALL_DIR)"/*.sh
	@chmod 644 "$(INSTALL_DIR)"/*.rsc "$(INSTALL_DIR)"/*.txt "$(INSTALL_DIR)"/*.conf
	@printf 'LOG_LEVEL=INFO\nPARALLEL_THREADS=4\n' > "$(CONFIG_DIR)/config.conf"
	@$(call log_success,Installation complete)

service-setup: install
	@$(call log,Configuring systemd units...)
	@if [ "$$EUID" -ne 0 ]; then \
		$(call log_error,Service setup requires root privileges); \
		echo 'Run with: sudo make service-setup'; \
		exit 1; \
	fi
	@mkdir -p "$(SERVICE_DIR)"
	@cat <<-'EOF' > "$(SERVICE_DIR)/chnroute.service"
	[Unit]
	Description=China Route Generator
	After=network-online.target
	Wants=network-online.target

	[Service]
	Type=oneshot
	ExecStart=$(INSTALL_DIR)/$(SCRIPT)
	WorkingDirectory=$(INSTALL_DIR)
	User=root
	Group=root
	Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

	[Install]
	WantedBy=multi-user.target
	EOF
	@cat <<-'EOF' > "$(SERVICE_DIR)/chnroute.timer"
	[Unit]
	Description=Daily China Route Generator Update
	Requires=chnroute.service

	[Timer]
	OnCalendar=daily
	Persistent=true
	RandomizedDelaySec=3600

	[Install]
	WantedBy=timers.target
	EOF
	@if command -v systemctl >/dev/null 2>&1; then \
		systemctl daemon-reload; \
	else \
		$(call log_warn,systemctl not found -- reload services manually if needed); \
	fi
	@$(call log_success,Systemd units created)
	@$(call log_info,Enable with: sudo systemctl enable --now chnroute.timer)

uninstall:
	@$(call log,Removing installed files...)
	@if [ "$$EUID" -ne 0 ]; then \
		$(call log_error,Uninstallation requires root privileges); \
		echo 'Run with: sudo make uninstall'; \
		exit 1; \
	fi
	@if command -v systemctl >/dev/null 2>&1; then \
		systemctl stop chnroute.timer 2>/dev/null || true; \
		systemctl stop chnroute.service 2>/dev/null || true; \
		systemctl disable chnroute.timer 2>/dev/null || true; \
		systemctl disable chnroute.service 2>/dev/null || true; \
		systemctl daemon-reload; \
	else \
		$(call log_warn,systemctl not found -- ensure services are removed manually if necessary); \
	fi
	@rm -rf "$(INSTALL_DIR)" "$(CONFIG_DIR)"
	@rm -f "$(SERVICE_DIR)/chnroute.service" "$(SERVICE_DIR)/chnroute.timer" 2>/dev/null || true
	@$(call log_success,Uninstallation complete)

package: clean generate validate-output
	@$(call log,Creating distribution package...)
	@version="$(VERSION)"; \
	if [ "$$version" = unknown ]; then \
		version=$$(date +%Y%m%d_%H%M%S); \
	fi; \
	pkg_name="chnroute-$$version"; \
	mkdir -p dist; \
	rm -rf "dist/$$pkg_name" "dist/$$pkg_name.tar.gz"; \
	mkdir -p "dist/$$pkg_name"; \
	for file in $(OUTPUT_FILES); do cp "$$file" "dist/$$pkg_name/"; done; \
	cp "$(SCRIPT)" "$(GFW_SCRIPT)" "dist/$$pkg_name/"; \
	cp -r lib "dist/$$pkg_name/"; \
	for doc in README.md README.en.md MAKEFILE_OPTIMIZATION_GUIDE.md SCRIPT_OPTIMIZATION_RECOMMENDATIONS.md; do \
		[ -f "$$doc" ] && cp "$$doc" "dist/$$pkg_name/"; \
	done; \
	cp include_list.txt "dist/$$pkg_name/" 2>/dev/null || true; \
	cp exclude_list.txt "dist/$$pkg_name/" 2>/dev/null || true; \
	printf 'chnroute %s\nGenerated on: %s\n' "$$version" "$$(date)" > "dist/$$pkg_name/README_PACKAGE.txt"; \
	( cd dist && tar -czf "$$pkg_name.tar.gz" "$$pkg_name" ); \
	@$(call log_success,Created package dist/$$pkg_name.tar.gz)

info:
	@printf '%bChina Route Generator%b\n' "$(COLOR_BOLD)" "$(COLOR_RESET)"
	@printf 'Version: %s\n' "$(VERSION)"
	@printf 'Repository: https://github.com/ruijzhan/chnroute\n'
	@printf 'Install Dir: %s\n' "$(INSTALL_DIR)"
	@printf 'Config Dir: %s\n\n' "$(CONFIG_DIR)"
	@printf '%bOutput files:%b\n' "$(COLOR_BLUE)" "$(COLOR_RESET)"
	@for file in $(OUTPUT_FILES); do \
		if [ -f "$$file" ]; then \
			size=$$(wc -c < "$$file"); \
			lines=$$(wc -l < "$$file"); \
			printf '  %s: %s lines, %s bytes\n' "$$file" "$$lines" "$$size"; \
		else \
			printf '  %s: (not generated)\n' "$$file"; \
		fi; \
	done
