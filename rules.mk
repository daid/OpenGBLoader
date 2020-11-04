BUILDDIR ?= .build
ROMDIR   ?= roms

Q        ?= @
MKDIR    ?= $(shell which mkdir)
RGBDS    ?=
RGBASM   ?= $(RGBDS)rgbasm
RGBLINK  ?= $(RGBDS)rgblink
RGBFIX   ?= $(RGBDS)rgbfix

INCDIRS  := src
WARNINGS := all extra
ASFLAGS  := $(addprefix -i,$(INCDIRS)) $(addprefix -W,$(WARNINGS))
LDFLAGS  :=

rwildcard  = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
MAINSRC    := $(call rwildcard,src,*.asm)
TESTLIBSRC := $(call rwildcard,tests/lib,*.asm)
TESTSRC    := $(wildcard tests/*.asm)
IMAGESRC   := $(wildcard tests/image.*.sh)

TESTROMS   := $(patsubst %.asm,$(ROMDIR)/%.gb,$(TESTSRC))
TESTIMAGES := $(patsubst %.sh,$(BUILDDIR)/%.image,$(IMAGESRC))

clean:
	-rm -rf $(BUILDDIR) $(ROMDIR)
.PHONY: clean

rebuild:
	$(MAKE) clean --no-print-directory
	$(MAKE) all --no-print-directory
.PHONY: rebuild

$(BUILDDIR)/%.o $(BUILDDIR)/%.mk: %.asm
	@$(MKDIR) -p $(dir $(BUILDDIR)/$*)
	@echo "Assembling $<"
	$(Q)$(RGBASM) $(ASFLAGS) -M $(BUILDDIR)/$*.mk -MG -MP -MQ $(BUILDDIR)/$*.o -MQ $(BUILDDIR)/$*.mk -o $(BUILDDIR)/$*.o $<

$(ROMDIR)/tests/%.gb $(ROMDIR)/tests/%.sym $(ROMDIR)/tests/%.map: $(patsubst %.asm,$(BUILDDIR)/%.o,$(MAINSRC) $(TESTLIBSRC) tests/%.asm)
	@$(MKDIR) -p $(@D)
	@echo "Linking $(ROMDIR)/tests/$*.gb"
	$(Q)$(RGBLINK) -p 0xff $(LDFLAGS) -m $(ROMDIR)/tests/$*.map -n $(ROMDIR)/tests/$*.sym -o $(ROMDIR)/tests/$*.gb $^
	$(Q)$(RGBFIX) -p 0xff -v $(ROMDIR)/tests/$*.gb

$(BUILDDIR)/tests/%.image: tests/%.sh
	@echo "Creating image $@"
	$(Q)sh tests/$*.sh $@

ifneq ($(MAKECMDGOALS),clean)
-include $(patsubst %.asm,$(BUILDDIR)/%.mk,$(MAINSRC) $(TESTLIBSRC) $(TESTSRC))
endif
