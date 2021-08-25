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
RUST_ALL_TARGETS = $(strip \
	x86_64-apple-ios \
	aarch64-apple-ios \
	aarch64-apple-ios-sim \
)
RUST_TARGETS = $(strip $(if $(RUST_ARCHS), \
	$(foreach arch,$(RUST_ARCHS),$(arch)-$(RUST_PLATFORM_NAME)), \
	$(RUST_ALL_TARGETS) \
))

ifeq ($(CONFIGURATION),Release)
RUST_CONFIGURATION = release
RUST_CONFIGURATION_FLAG = --release
else ifeq ($(strip $(filter-out Debug,$(CONFIGURATION))),)
RUST_CONFIGURATION = debug
RUST_CONFIGURATION_FLAG =
else
$(error Invalid CONFIGURATION $(CONFIGURATION))
endif

RUST_LIBRARIES = $(foreach target,$(RUST_TARGETS),target/$(target)/$(RUST_CONFIGURATION)/lib$(RUST_LIBRARY_NAME).a)
RUST_UNIVERSAL_LIBRARY = target/universal/$(RUST_CONFIGURATION)/lib$(RUST_LIBRARY_NAME).a

RUST_ALL_DEBUG_LIBRARIES = $(strip \
	$(foreach target,$(RUST_ALL_TARGETS), \
		target/$(target)/debug/lib$(RUST_LIBRARY_NAME).a \
	) \
)
RUST_ALL_RELEASE_LIBRARIES = $(strip \
	$(foreach target,$(RUST_ALL_TARGETS), \
		target/$(target)/release/lib$(RUST_LIBRARY_NAME).a \
	) \
)

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
	@echo "  submodules             -- update submodules"
	@echo
	@echo "Targets to build all supported rust targets ($(subst $(SP),$(COMMA) ,$(RUST_ALL_TARGETS)))"
	@echo "  rust-build-all         -- build rust debug and release libraries for all targets"
	@echo "  rust-build-debug-all   -- build rust debug libraries for all targets"
	@echo "  rust-build-release-all -- build rust release libraries for all targets"
	@echo "  rust-clean-all         -- clean rust debug and release build directories for all targets"
	@echo "  rust-clean-debug-all   -- build rust debug build directories for all targets"
	@echo "  rust-clean-release-all -- build rust release build directories for all targets"
	@echo
	@echo "Targets run from xcode, which build for targets based on the environment variables ARCHS, CONFIGURATION, and PLATFORM_NAME. Currently selected is \"$(RUST_CONFIGURATION)\" configuration for target(s) $(subst $(SP),$(COMMA) ,$(RUST_TARGETS)):"
	@echo "  rust-build           -- build rust libraries for selected configuration and targets"
	@echo "  rust-build-universal -- build rust universal library for selected configuration and targets"
	@echo "  rust-clean           -- clean rust build directory for selected configuration and targets"
	@echo
	@echo "Environment variables:"
	@echo "  ARCHS         -- architectures to build for (x86_64, arm64)"
	@echo "  CONFIGURATION -- build configuration (Release, Debug)"
	@echo "  PLATFORM_NAME -- platform to build for (iphoneos, iphonesimulator, macosx)"

.PHONY: submodules
submodules:
	git submodule foreach --recursive "git clean -xfd"
	git submodule foreach --recursive "git reset --hard"
	git submodule update --init

.PHONY: rust-build-all
rust-build-all: rust-build-debug-all rust-build-release-all

.PHONY: rust-build-debug-all
rust-build-debug-all: $(RUST_ALL_DEBUG_LIBRARIES)

.PHONY: rust-build-release-all
rust-build-release-all: $(RUST_ALL_RELEASE_LIBRARIES)

.PHONY: rust-clean-all
rust-clean-all: rust-clean-debug-all rust-clean-release-all

.PHONY: rust-clean-debug-all
rust-clean-debug-all:
	$(CARGO) clean -p voice-analyzer-rust
	$(foreach target,$(RUST_ALL_TARGETS), \
		$(CARGO) clean -p voice-analyzer-rust --target $(target) $(NL) \
	)

.PHONY: rust-clean-release-all
rust-clean-release-all:
	$(CARGO) clean -p voice-analyzer-rust --release
	$(foreach target,$(RUST_ALL_TARGETS), \
		$(CARGO) clean -p voice-analyzer-rust --release --target $(target) $(NL) \
	)

.PHONY: rust-build-universal
rust-build-universal: $(RUST_UNIVERSAL_LIBRARY)

.PHONY: rust-build
rust-build: $(RUST_LIBRARIES)

.PHONY: rust-clean
rust-clean:
	$(CARGO) clean -p voice-analyzer-rust $(RUST_CONFIGURATION_FLAG)
	$(foreach target,$(RUST_TARGETS), \
		$(CARGO) clean -p voice-analyzer-rust $(RUST_CONFIGURATION_FLAG) --target $(target) $(NL) \
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
		RUST_BUILD_STD="-Z build-std"; \
	fi; \
	if [ '' $(foreach target,$(RUST_NIGHTLY_TARGETS),-o '$*' = '$(target)') ]; then \
		CARGO_TOOLCHAIN="+nightly"; \
	fi; \
	$(CARGO) $${CARGO_TOOLCHAIN} build -p voice-analyzer-rust --target $* $${RUST_BUILD_STD}
