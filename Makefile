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
LICENSE_PLIST ?= license-plist

#
# path variables
#

resdir ?= VoiceAnalyzer/res

#
# rust library configurable variables
#

RUST_PACKAGE_NAME := voice-analyzer-rust
RUST_LIBRARY_NAME := $(subst -,_,$(RUST_PACKAGE_NAME))
RUST_BUILD_STD_TARGETS := $(strip \
	x86_64-apple-ios-macabi \
	aarch64-apple-ios-macabi \
)

#
# rust library computed variables
#

RUST_ARCHS = $(subst arm64,aarch64,$(ARCHS))
RUST_ALL_TARGETS = $(strip \
	x86_64-apple-ios \
	aarch64-apple-ios \
	aarch64-apple-ios-sim \
)
RUST_TARGETS = $(strip $(if $(RUST_ARCHS), \
	$(foreach arch,$(RUST_ARCHS),$(arch)-$(strip \
		$(subst iphoneos,apple-ios, \
		$(subst iphonesimulator, \
			$(if $(subst aarch64,,$(arch)), \
				apple-ios, \
				apple-ios-sim \
			), \
		$(subst macosx,apple-darwin, \
			$(PLATFORM_NAME)))) \
	)), \
	$(RUST_ALL_TARGETS) \
))

ifeq ($(CONFIGURATION),App Store Release)
RUST_CONFIGURATION = release
RUST_CONFIGURATION_FLAG = --release
else ifeq ($(CONFIGURATION),Testable Release)
RUST_CONFIGURATION = release
RUST_CONFIGURATION_FLAG = --release
else ifeq ($(strip $(filter-out Debug,$(CONFIGURATION))),)
RUST_CONFIGURATION = debug
RUST_CONFIGURATION_FLAG =
else
$(error Invalid CONFIGURATION $(CONFIGURATION))
endif

RUST_LIBRARIES = $(foreach target,$(RUST_TARGETS),target/$(target)/$(RUST_CONFIGURATION)/lib$(RUST_LIBRARY_NAME).a)

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
	@echo "  acknowledgements       -- compile all copyright acknowledgements"
	@echo "  rust-acknowledgements  -- compile rust crate copyright acknowledgements with cargo-about"
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
	@echo "  rust-clean           -- clean rust build directory for selected configuration and targets"
	@echo
	@echo "Environment variables:"
	@echo "  ARCHS         -- architectures to build for (x86_64, arm64)"
	@echo "  CONFIGURATION -- build configuration (App Store Release, Debug)"
	@echo "  PLATFORM_NAME -- platform to build for (iphoneos, iphonesimulator, macosx)"

.PHONY: acknowledgements
acknowledgements: rust-acknowledgements swift-acknowledgements

.PHONY: swift-acknowledgements
swift-acknowledgements: $(resdir)/Settings.bundle/SwiftAcknowledgements.latest_result.txt

$(resdir)/Settings.bundle/SwiftAcknowledgements.latest_result.txt: VoiceAnalyzer.xcworkspace/xcshareddata/swiftpm/Package.resolved
	if ! which $(LICENSE_PLIST) >/dev/null; then echo "Please run brew install mono0926/license-plist/license-plist"; exit 1; fi
	$(LICENSE_PLIST) --output-path $(dir $@) --prefix $(patsubst %.latest_result.txt,%,$(notdir $@)) --single-page

.PHONY: rust-acknowledgements
rust-acknowledgements: $(resdir)/Settings.bundle/RustAcknowledgements.plist

$(resdir)/Settings.bundle/RustAcknowledgements.plist: $(resdir)/RustAcknowledgements.plist.hbs Cargo.lock
	$(CARGO) install cargo-about
	$(CARGO) about generate $< > $@

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

target/%/release/lib$(RUST_LIBRARY_NAME).a: FORCE
	if [ '' $(foreach target,$(RUST_BUILD_STD_TARGETS),-o '$*' = '$(target)') ]; then \
		export RUSTC_BOOTSTRAP=1; \
		RUST_BUILD_STD="-Z build-std"; \
	fi; \
	$(CARGO) $${CARGO_TOOLCHAIN} build -p voice-analyzer-rust --release --target $* $${RUST_BUILD_STD}

target/%/debug/lib$(RUST_LIBRARY_NAME).a: FORCE
	if [ '' $(foreach target,$(RUST_BUILD_STD_TARGETS),-o '$*' = '$(target)') ]; then \
		export RUSTC_BOOTSTRAP=1; \
		RUST_BUILD_STD="-Z build-std"; \
	fi; \
	$(CARGO) $${CARGO_TOOLCHAIN} build -p voice-analyzer-rust --target $* $${RUST_BUILD_STD}
