all: tests
	
.PHONY: all

include rules.mk

TEST_TARGETS := $(foreach ROM,$(TESTROMS),$(foreach IMAGE,$(TESTIMAGES),$(ROM)-XXX-$(IMAGE)))
$(TEST_TARGETS): ROM = $(word 1,$(subst -XXX-, ,$@))
$(TEST_TARGETS): IMAGE = $(word 2,$(subst -XXX-, ,$@))
$(TEST_TARGETS): $(ROM) $(IMAGE)
	@echo "Running test $(ROM) with $(IMAGE)"
	$(eval RES="$(shell $(BADBOY) -c 10000000 $(ROM) -e $(IMAGE) 2>/dev/null)")
	@echo "$(RES)"

tests: $(TESTROMS) $(TESTIMAGES) $(TEST_TARGETS)
.PHONY: tests
