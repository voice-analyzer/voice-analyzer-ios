.PHONY: default
default: help

.PHONY: help
help:
	@echo "Targets:"
	@echo "  submodules -- update submodules"

.PHONY: submodules
submodules:
	git submodule foreach --recursive "git clean -xfd"
	git submodule foreach --recursive "git reset --hard"
	git submodule update --init
