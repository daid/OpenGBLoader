BUILDDIR ?= .build
ROMDIR   ?= roms

Q        ?= @
MKDIR    ?= $(shell which mkdir)
RGBDS    ?=
RGBASM   ?= $(RGBDS)rgbasm
RGBLINK  ?= $(RGBDS)rgblink
RGBFIX   ?= $(RGBDS)rgbfix
RGBGFX   ?= $(RGBDS)rgbgfx

INCDIRS  := src src/include $(BUILDDIR)/res
WARNINGS := all extra
ASFLAGS  := $(addprefix -i,$(INCDIRS)) $(addprefix -W,$(WARNINGS))
LDFLAGS  :=

rwildcard  = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
MAINSRC    := $(filter-out src/ezgb.asm,$(call rwildcard,src,*.asm))
TESTLIBSRC := $(call rwildcard,tests/lib,*.asm)
TESTSRC    := $(wildcard tests/*.asm)
IMAGESRC   := $(wildcard tests/image.*.sh)

TESTROMS   := $(patsubst %.asm,$(ROMDIR)/%.gb,$(TESTSRC))
TESTIMAGES := $(patsubst %.sh,$(BUILDDIR)/%.image,$(IMAGESRC))

VPATH      := $(BUILDDIR)/res

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
	$(Q)$(RGBASM) $(ASFLAGS) -M $(BUILDDIR)/$*.mk -MG -MQ $(BUILDDIR)/$*.o -MQ $(BUILDDIR)/$*.mk -o $(BUILDDIR)/$*.o $<

$(ROMDIR)/ezgb.dat $(ROMDIR)/main.sym $(ROMDIR)/ezgb.map: $(patsubst %.asm,$(BUILDDIR)/%.o,$(MAINSRC) $(BUILDDIR)/src/ezgb.o)
	@$(MKDIR) -p $(@D)
	@echo "Linking $(ROMDIR)/ezgb.dat"
	$(Q)$(RGBLINK) -p 0xff $(LDFLAGS) -m $(ROMDIR)/ezgb.map -n $(ROMDIR)/ezgb.sym -o $(ROMDIR)/ezgb.dat $^
	$(Q)$(RGBFIX) -p 0xff -v $(ROMDIR)/ezgb.dat

$(ROMDIR)/tests/%.gb $(ROMDIR)/tests/%.sym $(ROMDIR)/tests/%.map: $(patsubst %.asm,$(BUILDDIR)/%.o,$(MAINSRC) $(TESTLIBSRC) tests/%.asm)
	@$(MKDIR) -p $(@D)
	@echo "Linking $(ROMDIR)/tests/$*.gb"
	$(Q)$(RGBLINK) -p 0xff $(LDFLAGS) -m $(ROMDIR)/tests/$*.map -n $(ROMDIR)/tests/$*.sym -o $(ROMDIR)/tests/$*.gb $^
	$(Q)$(RGBFIX) -p 0xff -v $(ROMDIR)/tests/$*.gb

$(BUILDDIR)/res/%.2bpp: res/%.png
	@$(MKDIR) -p $(dir $(BUILDDIR)/res/$*)
	@echo "Converting $<"
	$(Q)$(RGBGFX) -o $(BUILDDIR)/res/$*.2bpp $<

$(BUILDDIR)/tests/%.image: tests/%.sh tests/lib/image.sh
	@echo "Creating image $@"
	$(Q)sh tests/$*.sh $@

ifneq ($(MAKECMDGOALS),clean)
-include $(patsubst %.asm,$(BUILDDIR)/%.mk,$(MAINSRC) $(TESTLIBSRC) $(TESTSRC))
endif
