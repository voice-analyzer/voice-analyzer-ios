#
# xcode build environment variables
#

ARCHS ?=
PLATFORM_NAME ?=
CONFIGURATION ?=

#
# tool path variables
#

CARGO ?= cargo
LIPO ?= lipo

#
# rust library configurable variables
#

RUST_PACKAGE_NAME := voice-analyzer-rust
RUST_LIBRARY_NAME := $(subst -,_,$(RUST_PACKAGE_NAME))
RUST_NIGHTLY_TARGETS := $(strip \
	aarch64-apple-ios-sim \
)
RUST_BUILD_STD_TARGETS := $(strip \
	x86_64-apple-ios-macabi \
	aarch64-apple-ios-macabi \
)

#
# rust library computed variables
#

RUST_ARCHS = $(subst arm64,aarch64,$(ARCHS))
RUST_PLATFORM_NAME = $(strip \
	$(subst iphoneos,apple-ios, \
	$(subst iphonesimulator,apple-ios-sim, \
	$(subst macosx,apple-darwin, \
		$(PLATFORM_NAME)))) \
)
RUST_TARGETS = $(strip $(if $(RUST_ARCHS), \
	$(foreach arch,$(RUST_ARCHS),$(arch)-$(RUST_PLATFORM_NAME)), \
	x86_64-apple-ios \
	aarch64-apple-ios \
	) \
)
RUST_CONFIGURATION = $(if $(findstring,Release,CONFIGURATION),debug,release)
RUST_LIBRARIES = $(foreach target,$(RUST_TARGETS),target/$(target)/$(RUST_CONFIGURATION)/lib$(RUST_LIBRARY_NAME).a)
RUST_UNIVERSAL_LIBRARY = target/universal/$(RUST_CONFIGURATION)/lib$(RUST_LIBRARY_NAME).a

#
# utility variables
#

NIL :=
SP := $(NIL) $(NIL)
COMMA := ,
define NL


endef

#
# phony targets
#

.PHONY: default
default: help

.PHONY: help
help:
	@echo "Targets:"
	@echo "  submodules           -- update submodules"
	@echo "  rust-build           -- build rust $(RUST_CONFIGURATION) libraries for $(subst $(SP),$(COMMA),$(RUST_TARGETS))"
	@echo "  rust-build-universal -- build rust universal $(RUST_CONFIGURATION) library for $(subst $(SP),$(COMMA),$(RUST_TARGETS))"
	@echo "  rust-clean           -- clean rust build directory for $(subst $(SP),$(COMMA),$(RUST_TARGETS))"

.PHONY: submodules
submodules:
	git submodule foreach --recursive "git clean -xfd"
	git submodule foreach --recursive "git reset --hard"
	git submodule update --init

.PHONY: rust-build-universal
rust-build-universal: $(RUST_UNIVERSAL_LIBRARY)

.PHONY: rust-build
rust-build: $(RUST_LIBRARIES)

.PHONY: rust-clean
rust-clean:
	$(CARGO) clean -p voice-analyzer-rust --release
	$(foreach target,$(RUST_TARGETS), \
		$(CARGO) clean -p voice-analyzer-rust --release --target $(target) $(NL) \
	)

#
# utility targets
#

.PHONY: FORCE
FORCE:

#
# rust targets
#

$(RUST_UNIVERSAL_LIBRARY): $(RUST_LIBRARIES)
	mkdir -p $(dir $@)
	$(LIPO) -create -output $@ $^

target/%/release/lib$(RUST_LIBRARY_NAME).a: FORCE
	if [ '' $(foreach target,$(RUST_BUILD_STD_TARGETS),-o '$*' = '$(target)') ]; then \
		export RUSTC_BOOTSTRAP=1; \
		RUST_BUILD_STD="-Z build-std"; \
	fi; \
	if [ '' $(foreach target,$(RUST_NIGHTLY_TARGETS),-o '$*' = '$(target)') ]; then \
		CARGO_TOOLCHAIN="+nightly"; \
	fi; \
	$(CARGO) $${CARGO_TOOLCHAIN} build -p voice-analyzer-rust --release --target $* $${RUST_BUILD_STD}

target/%/debug/lib$(RUST_LIBRARY_NAME).a: FORCE
	if [ '' $(foreach target,$(RUST_BUILD_STD_TARGETS),-o '$*' = '$(target)') ]; then \
		export RUSTC_BOOTSTRAP=1; \
		RUST_BUILD_STD=-Z build-std; \
	fi; \
	$(CARGO) build -p voice-analyzer-rust --debug --target $* $${RUST_BUILD_STD}
