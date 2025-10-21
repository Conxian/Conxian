# Makefile for formal verification using K-Framework

# Configuration
K_VERSION ?= 5.6.7
K_BIN = ~/.local/bin/kframework-${K_VERSION}
K_BIN_URL = https://github.com/runtimeverification/k/releases/download/v${K_VERSION}/kframework_${K_VERSION}_amd64.deb

# Contract files
CONTRACTS = $(wildcard ../contracts/**/*.clar)
VERIFICATION_FILES = $(patsubst ../contracts/%.clar, %.k, $(CONTRACTS))

# Default target
all: setup verify

# Setup K-Framework
setup:
	@echo "Setting up K-Framework..."
	wget -O kframework.deb $(K_BIN_URL)
	sudo apt install -y ./kframework.deb
	rm kframework.deb

# Generate K specifications from Clarity contracts
%.k: ../contracts/%.clar
	@echo "Generating K spec for $<"
	mkdir -p $(@D)
	python3 generate_kspec.py $< > $@

# Verify a contract
verify: $(VERIFICATION_FILES)
	@echo "Verifying contracts..."
	for spec in $^; do \
		kprove $$spec --haskell-backend-command "kore-exec --version" || exit 1; \
	done

clean:
	rm -f *.k

.PHONY: all setup verify clean
