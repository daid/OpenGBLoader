all:

.PHONY: all

include rules.mk

all: $(ROMDIR)/ezgb.dat

BADBOY ?= BadBoy

TEST_TARGETS := $(foreach SRC,$(TESTSRC),$(foreach IMAGE,$(TESTIMAGES),$(SRC)-XXX-$(IMAGE)))
$(TEST_TARGETS): SRC = $(word 1,$(subst -XXX-, ,$@))
$(TEST_TARGETS): ROM = $(patsubst %.asm,$(ROMDIR)/%.gb,$(SRC))
$(TEST_TARGETS): IMAGE = $(word 2,$(subst -XXX-, ,$@))
$(TEST_TARGETS):
	@echo "Test: $(SRC) $(IMAGE)"
	$(Q)BADBOY=$(BADBOY) tests/runTest.sh $(ROM) $(IMAGE) $(SRC)
.PHONY: $(TEST_TARGETS)

tests: $(TESTROMS) $(TESTIMAGES) $(TEST_TARGETS)
.PHONY: tests
