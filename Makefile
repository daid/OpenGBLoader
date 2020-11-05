all:
	
.PHONY: all

include rules.mk

BADBOY ?= BadBoy

TEST_TARGETS := $(foreach ROM,$(TESTROMS),$(foreach IMAGE,$(TESTIMAGES),$(ROM)-$(IMAGE)))
$(TEST_TARGETS): ROM = $(word 1,$(subst -, ,$@))
$(TEST_TARGETS): IMAGE = $(word 2,$(subst -, ,$@))
$(TEST_TARGETS):
	@echo "Test: $(ROM) $(IMAGE)"
	@#TODO: Check result of test.
	@$(BADBOY) -c 10000000 $(ROM) -e $(IMAGE) 2>/dev/null
.PHONY: $(TEST_TARGETS)

tests: $(TESTROMS) $(TESTIMAGES) $(TEST_TARGETS)
.PHONY: tests
