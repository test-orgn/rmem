#=========================================================================================================#
#                                                                                                         #
#                rmem executable model                                                                    #
#                =====================                                                                    #
#                                                                                                         #
#  This file is:                                                                                          #
#                                                                                                         #
#  Copyright Peter Sewell, University of Cambridge                                            2011-2017   #
#  Copyright Shaked Flur, University of Cambridge                                             2015-2018   #
#  Copyright Jon French, University of Cambridge                                        2015, 2017-2018   #
#  Copyright Pankaj Pawan, IIT Kanpur and INRIA (when this work was done)                          2011   #
#  Copyright Christopher Pulte, University of Cambridge                                       2015-2018   #
#  Copyright Susmit Sarkar, University of St Andrews                               2011-2012, 2014-2015   #
#  Copyright Ohad Kammar, University of Cambridge (when this work was done)                   2013-2014   #
#  Copyright Kathy Gray, University of Cambridge (when this work was done)                   2015, 2017   #
#  Copyright Francesco Zappa Nardelli, INRIA, Paris, France                                        2011   #
#  Copyright Robert Norton-Wright, University of Cambridge                                    2016-2017   #
#  Copyright Luc Maranget, INRIA, Paris, France                                         2011-2012, 2015   #
#  Copyright Sela Mador-Haim, University of Pennsylvania (when this work was done)                 2012   #
#  Copyright Jean Pichon-Pharabod, University of Cambridge                                    2013-2014   #
#  Copyright Gabriel Kerneis, University of Cambridge (when this work was done)                    2014   #
#  Copyright Kayvan Memarian, University of Cambridge                                              2012   #
#                                                                                                         #
#  All rights reserved.                                                                                   #
#                                                                                                         #
#  It is part of the rmem tool, distributed under the 2-clause BSD licence in                             #
#  LICENCE.txt.                                                                                           #
#                                                                                                         #
#=========================================================================================================#

OPAM := $(shell which opam 2> /dev/null)
OCAMLBUILD := $(shell which ocamlbuild 2> /dev/null)
ifeq ($(OCAMLBUILD),)
  $(warning *** cannot find ocamlbuild, please install it or set OCAMLBUILD to point to it)
  OCAMLBUILD := echo "*** cannot find ocamlbuild" >&2 && false
endif



# _OCAMLFIND must match the one ocamlbuild will use, hence the 'override'
override _OCAMLFIND := $(shell $(OCAMLBUILD) -which ocamlfind 2> /dev/null)
# for ocamlc or ocamlopt use '$(_OCAMLFIND) ocamlc' or '$(_OCAMLFIND) ocamlopt'

default:
	$(MAKE) rmem
.PHONY: default
.DEFAULT_GOAL: default

## help: #############################################################

define HELP_MESSAGE
In addition to the dependencies described below, rmem requires OCaml\
4.02.3 or greater and ocamlbuild. The variable OCAMLBUILD can be used\
to set a specific ocamlbuild executable.

make             - same as 'make rmem'
make clean       - remove all the files that were generated by the build process

make rmem [UI={text|web|isabelle|headless}] [MODE={debug|opt|profile|byte}] [ISA=...]
  UI    text - (default) build the text interface; web - build the web interface;
        isabelle - build Isabelle theory files; headless - build the text interface
        without interactive mode (does not require lambda-term).
  MODE  compile to bytecode (debug - default), native (opt) or p.native (profile)
  ISA   comma separated list of ISA models to include ($(ALLISAS)).

make clean_ocaml - 'ocamlbuild -clean'

make clean_install_dir [INSTALLDIR=<path>]     - removes $(INSTALLDIR)
make install_web_interface [INSTALLDIR=<path>] - build the web-interface and install it in $(INSTALLDIR)
make serve [INSTALLDIR=<path>] [PORT=<port>]   - serve the web-interface in $(INSTALLDIR)

make isabelle [ISA=...] - generate theory files for Isabelle (in ./build_isabelle_concurrency_model/)

make sloc_concurrency_model - use sloccount on the .lem files that were used in the last build
endef

help:
	$(info $(HELP_MESSAGE))
	@:
.PHONY: help

## utils: ############################################################
FORCE:
.PHONY: FORCE

# $(call equal,<x>,<y>) expands to 1 if the strings <x> and <y> are
# equivalent, otherwise it expands to the empty string. For example:
# $(if $(call equal,<x>,<y>),echo "equal",echo "not equal")
define _equal
  ifeq "$(1)" "$(2)"
    _equal_res := 1
  else
    _equal_res :=
  endif
endef
equal=$(eval $(call _equal,$(1),$(2)))$(_equal_res)
notequal=$(if $(call equal,$(1),$(2)),,1)

add_ocaml_exts = $(foreach s,.d.byte .byte .native .p.native,$(addsuffix $(s),$(1)))

comma=,
split_on_comma = $(subst $(comma), ,$(1))

# in the recipe of a rule $(call git_version,<the-git-dir>)
# will print OCaml code matching the signature Git from src_top/versions.ml
git_version =\
  { printf -- '(* auto generated by make *)\n\n' &&\
    printf -- '(* git -C $(1) describe --dirty --always --abbrev= *)\n' &&\
    printf -- 'let describe : string = {|%s|}\n\n' "$$(git -C $(1) describe --dirty --always --abbrev=)" &&\
    printf -- '(* git -C $(1) log -1 --format=%%ci *)\n' &&\
    printf -- 'let last_changed : string = {|%s|}\n\n' "$$(git -C $(1) log -1 --format=%ci)" &&\
    printf -- '(* git -C $(1) status -suno *)\n' &&\
    printf -- 'let status : string = {|\n%s|}\n' "$$(git -C $(1) status -suno)";\
  }

######################################################################

MODE=$(if $(call equal,$(UI),web),opt,debug)
.PHONY: MODE
ifeq ($(MODE),debug)
  EXT = d.byte
  JSOCFLAGS=--pretty --no-inline --debug-info --source-map
else ifeq ($(MODE),byte)
  EXT = byte
else ifeq ($(MODE),opt)
  EXT = native
  JSOCFLAGS=--opt 3
else ifeq ($(MODE),profile)
  EXT = p.native
else
  $(error '$(MODE)' is not a valid MODE value, must be one of: opt, profile, debug, byte)
endif

UI=text
.PHONY: UI
ifeq ($(UI),isabelle)
  CONCSENTINEL = build_isabelle_concurrency_model/make_sentinel
else
  CONCSENTINEL = build_concurrency_model/make_sentinel
  ifeq ($(UI),web)
    ifeq ($(MODE),opt)
      EXT = byte
    else ifeq ($(MODE),profile)
      $(error 'profile' is not a valid MODE value when UI=web, must be one of: opt, debug, byte)
    endif
  else ifeq ($(UI),text)
  else ifeq ($(UI),headless)
  else
    $(error '$(UI)' is not a valid UI value, must be one of: text, web, headless, isabelle)
  endif
endif

# the following has an effect only if ISA is not provided on the CLI;
ifneq ($(wildcard $(CONCSENTINEL)),)
  ISA := $(shell cat $(CONCSENTINEL))
else
  ISA := PPCGEN,AArch64,RISCV,X86
endif
.PHONY: ISA

ISA_LIST := $(call split_on_comma,$(ISA))
# make sure the ISAs are valid options, and not empty
ALLISAS = PPCGEN AArch64 MIPS RISCV X86
$(if $(strip $(ISA_LIST)),,$(error ISA cannot be empty, try $(ALLISAS)))
$(foreach i,$(ISA_LIST),$(if $(filter $(i),$(ALLISAS)),,$(error $(i) is not a valid ISA, try $(ALLISAS))))

# if the Lem model was built with a different set of ISAs we force a rebuild
ifneq ($(wildcard $(CONCSENTINEL)),)
  # make_sentinel exists
  ifneq ($(ISA),$(shell cat $(CONCSENTINEL)))
    FORCECONCSENTINEL = FORCE
  endif
endif

show_sentinel_isa:
	@$(if $(wildcard build_concurrency_model/make_sentinel),\
	  printf -- 'OCaml: ISA=%s\n' "$$(cat build_concurrency_model/make_sentinel)",\
	  echo "OCaml: no sentinel")
	@$(if $(wildcard build_isabelle_concurrency_model/make_sentinel),\
	  printf -- 'Isabelle: ISA=%s\n' "$$(cat build_isabelle_concurrency_model/make_sentinel)",\
	  echo "Isabelle: no sentinel")
.PHONY: show_sentinel_isa

## the main executable: ##############################################

OCAMLBUILD_FLAGS += -use-ocamlfind
OCAMLBUILD_FLAGS += -plugin-tag "package(str)"
OCAMLBUILD_FLAGS += -I src_top/$(UI)
# if flambda is supported, perform more optimisation than usual
ifeq ($(MODE),opt)
  ifeq ($(shell $(_OCAMLFIND) ocamlopt -config | grep -q '^flambda:[[:space:]]*true' && echo true),true)
    OCAMLBUILD_FLAGS += -tag 'optimize(3)'
  endif
endif
# this is needed when building on bim and bom:
ifeq ($(shell $(_OCAMLFIND) ocamlopt -flarge-toc > /dev/null 2>&1 && echo true),true)
  OCAMLBUILD_FLAGS += -ocamlopt 'ocamlopt -flarge-toc'
endif

rmem: $(UI)
.PHONY: rmem

ppcmem:
	$(error did you mean rmem? see 'make help')
.PHONY: ppcmem

text:     override UI = text
headless: override UI = headless
text headless:
	$(MAKE) UI=$(UI) get_all_deps
	$(MAKE) UI=$(UI) main
	ln -f -s main.$(EXT) rmem
	@echo "*** DONE: $@ UI=$(UI) MODE=$(MODE) ISA=$(ISA)"
.PHONY: text headless
CLEANFILES += rmem

web: override UI=web
web:
	$(MAKE) UI=$(UI) get_all_deps
	$(MAKE) UI=$(UI) webppc
	$(MAKE) UI=$(UI) system.js
	@echo "*** DONE: web UI=$(UI) MODE=$(MODE) ISA=$(ISA)"
.PHONY: web

isabelle: override UI=isabelle
isabelle:
	$(MAKE) UI=$(UI) get_all_deps
	$(MAKE) UI=$(UI) build_isabelle_concurrency_model/make_sentinel
.PHONY: isabelle

.PHONY: get_all_deps

HIGHLIGHT := $(if $(MAKE_TERMOUT),| scripts/highlight.sh -s)
main webppc: src_top/share_dir.ml version.ml build_concurrency_model/make_sentinel marshal_defs
	rm -f $@.$(EXT)
	ulimit -s 33000; $(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_top/$@.$(EXT) $(HIGHLIGHT)
#	when piping through the highlight script we lose the exit status
#	of ocamlbuild; check for the target existence instead:
	@[ -f $@.$(EXT) ]
.PHONY: main webppc
CLEANFILES += $(call add_ocaml_exts,main)
CLEANFILES += $(call add_ocaml_exts,webppc)

clean_ocaml:
	$(OCAMLBUILD) -clean
.PHONY: clean_ocaml

version.ml: FORCE
	{ $(call git_version,./) &&\
	  printf -- '\n' &&\
	  printf -- 'let ocaml : string = {|%s|}\n\n' "$$($(_OCAMLFIND) ocamlc -vnum)" &&\
	  printf -- 'let lem : string = {|%s|}\n\n' "$$($(LEM) -v)" &&\
	  printf -- 'let sail_legacy : string = {|%s|}\n\n' "$$(sail-legacy -v)" &&\
	  printf -- 'let sail : string = {|%s|}\n\n' "$$(sail -v)" &&\
	  printf -- 'let libraries : (string * string) list = [\n' &&\
	  $(_OCAMLFIND) query -format '  ({|%p|}, {|%v|});' $(PKGS) &&\
	  printf -- ']\n';\
	} > $@
CLEANFILES += version.ml


# the prerequisite webppc.$(EXT) does not trigger a rebuild of webppc,
# that has to be done manually before updating system.js
system.js: webppc.$(EXT)
	rm -f system.map
	js_of_ocaml $(JSOCFLAGS) +nat.js src_web_interface/web_assets/BigInteger.js src_web_interface/web_assets/zarith.js src_marshal_defs/primitives.js $< -o $@
CLEANFILES += system.js system.map

clean: clean_ocaml
	rm -f $(CLEANFILES)
	rm -rf $(CLEANDIRS)
.PHONY: clean

## marshal defs ######################################################

MARSHAL_DEFS_FILES = PPCGen.defs AArch64.defs MIPS64.defs X86.defs



marshal_defs: build_concurrency_model/make_sentinel
	rm -f marshal_defs.native
	$(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_marshal_defs/marshal_defs.native $(HIGHLIGHT)
#	when piping through the highlight script we lose the exit status
#	of ocamlbuild; check for the target existance instead:
	@[ -f marshal_defs.native ]
	$(MAKE) $(MARSHAL_DEFS_FILES)
.PHONY: marshal_defs
CLEANFILES += marshal_defs.native
CLEANFILES += MARSHAL_DEFS_FILES

$(MARSHAL_DEFS_FILES): %.defs: marshal_defs.native
	./marshal_defs.native -$* $@
CLEANFILES += $(MARSHAL_DEFS_FILES)



## install for opam ##################################################

INSTALL_DIR ?= .
SHARE_DIR ?= share

src_top/share_dir.ml:
	echo "let share_dir = \"$(SHARE_DIR)\"" > src_top/share_dir.ml
CLEANFILES += src_top/share_dir.ml

install: 
	mkdir -p $(INSTALL_DIR)/bin
	mkdir -p $(SHARE_DIR)
	cp rmem $(INSTALL_DIR)/bin
	cp *.defs $(SHARE_DIR)


## install the web-interface #########################################

INSTALLDIR = ~/public_html/rmem

# install tests (defines install_<isa>_tests and litmus_library.json)
include web_interface_tests.mk

$(INSTALLDIR):
	mkdir -p $@

# because all the prerequisites are after the | the recipe will execute
# only if the target does not already exist (i.e. if you manually installed
# .htaccess it will not be overwritten)
$(INSTALLDIR)/.htaccess: | $(INSTALLDIR)
	cp src_web_interface/example.htaccess $@

console_help_printer:
	rm -f console_help_printer.native
	$(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_top/console_help_printer.native
.PHONY: console_help_printer
CLEANFILES += console_help_printer.native

$(INSTALLDIR)/help.html: src_web_interface/help.md console_help_printer.native | $(INSTALLDIR)
	{ echo '<!-- WARNING: AUTOGENERATED FILE; DO NOT EDIT (edit $< instead) -->';\
	  gpp -U "" "" "(" "," ")" "(" ")" "#" "" -M "#" "\n" " " " " "\n" "(" ")" $(if $(or $(call equal,$(origin ANON),undefined),$(call notequal,$(ANON),false)),$(if $(ANON),-D ANON,)) $< | pandoc -f markdown -t html -s --toc --css rmem.css;\
	  echo "<pre><code>";\
	  ./console_help_printer.native;\
	  echo "</code></pre>";\
	} > $@

install_web_interface: web $(INSTALLDIR)
# TODO:	rm -rf $(INSTALLDIR)/*
	cp -r src_web_interface/* $(INSTALLDIR)/
	cp $(MARSHAL_DEFS_FILES) $(INSTALLDIR)
	cp $(INSTALL_DEFS_FILES) $(INSTALLDIR)
	cp system.js $(INSTALLDIR)
	[ ! -e system.map ] || cp system.map $(INSTALLDIR)
	$(MAKE) console_help_printer
	$(MAKE) $(INSTALLDIR)/help.html
	$(MAKE) $(INSTALLDIR)/.htaccess
	$(MAKE) $(foreach isa,$(ISA_LIST),install_$(isa)_tests)
	$(MAKE) $(INSTALLDIR)/litmus_library.json
.PHONY: install_web_interface

clean_install_dir:
	rm -rf $(INSTALLDIR)
.PHONY: clean_install_dir

serve: PYTHON := $(or $(shell which python3 2> /dev/null),$(shell which python2 2> /dev/null))
serve: PORT=8000
serve:
	@xdg-open "http://127.0.0.1:$(PORT)/index.html" || echo '*** open "http://127.0.0.1:$(PORT)/index.html" in your web-browser'
	$(if $(PYTHON),\
	  cd $(INSTALLDIR) && $(PYTHON) $(realpath scripts/serve.py) $(PORT),\
	  $(error Could not find either python3 or python2 to run simple web server.))
.PHONY: serve



ifeq ($(UI),text)
  OCAMLBUILD_FLAGS += -tag-line '"src_top/main.$(EXT)" : package(lambda-term)'
else ifeq ($(UI),headless)
else ifeq ($(UI),web)
endif



saildir ?= $(shell opam var sail-legacy:share)
ifeq ($(saildir),)
  $(error cannot find (the share directory of) the opam package sail-legacy)
endif

sail2dir ?= $(shell opam var sail:share)
ifeq ($(sail2dir),)
  $(error cannot find (the share directory of) the opam package sail)
endif

riscvdir ?= $(shell opam var sail-riscv:share)
ifeq ($(riscvdir),)
  $(error cannot find (the share directory of) the opam package sail-riscv)
endif

lemdir ?= $(shell opam var lem:share)
ifeq ($(lemdir),)
  $(error cannot find (the share directory of) the opam package lem)
endif

linksemdir ?= $(shell opam var linksem:share)
ifeq ($(linksemdir),)
  $(error cannot find (the share directory of) the opam package linksem)
endif


######################################################################

# get_lem_library: MAKEOVERRIDES := $(filter-out INSTALLDIR=%,$(MAKEOVERRIDES))
# get_lem_library:
# 	LEM -v > lem_version.ml
# .PHONY: get_lem_library
# get_all_deps: get_lem_library
# CLEANFILES += lem_version.ml

# get_linksem: MAKEOVERRIDES := $(filter-out INSTALLDIR=%,$(MAKEOVERRIDES))
# get_linksem:
# 	$(MAKE) -C $(linksemdir) install
# 	$(call git_version,$(linksemdir)) > linksem_version.ml
# .PHONY: get_linksem
# get_all_deps: get_linksem
# CLEANFILES += linksem_version.ml

get_sail:
	rm -rf build_sail_interp
	mkdir -p build_sail_interp
	cp -a $(saildir)/src/lem_interp/instruction_extractor.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/interp.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/interp_ast.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/interp_lib.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/interp_interface.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/interp_inter_imp.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/interp_utilities.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/sail_impl_base.lem build_sail_interp
	cp -a $(saildir)/src/lem_interp/printing_functions.ml* build_sail_interp
	cp -a $(saildir)/src/lem_interp/pretty_interp.ml* build_sail_interp
#	mkdir -p build_sail_interp/pprint/src
#	cp -a $(saildir)/src/pprint/src/*.ml* build_sail_interp/pprint/src
	rm -rf build_sail_shallow_embedding
	mkdir -p build_sail_shallow_embedding
	cp -a $(saildir)/src/gen_lib/*.lem  build_sail_shallow_embedding
	# sail-legacy -v > sail_version.ml
.PHONY: get_sail
get_all_deps: get_sail
CLEANDIRS += build_sail_interp
CLEANDIRS += build_sail_shallow_embedding
# CLEANFILES += sail_version.ml

get_sail2:
	rm -rf build_sail2_shallow_embedding
	mkdir -p build_sail2_shallow_embedding
	cp -a $(sail2dir)/src/gen_lib/*.lem  build_sail2_shallow_embedding
	cp -a $(sail2dir)/src/lem_interp/*.lem build_sail2_shallow_embedding
#	cp -a $(sail2dir)/src/sail_lib.ml build_sail2_shallow_embedding
#	cp -a $(sail2dir)/src/util.ml build_sail2_shallow_embedding
	# sail -v > sail2_version.ml
.PHONY: get_sail2
get_all_deps: get_sail2
CLEANDIRS += build_sail2_shallow_embedding
#CLEANFILES += sail2_version.ml

## import ISA models #################################################

get_all_deps: get_all_isa_models
.PHONY: get_all_isa_models

get_isa_model_%: ISABUILDDIR ?= build_isa_models/$*
get_isa_model_%: BUILDISA ?= true
get_isa_model_%: BUILDISATARGET ?= all
get_isa_model_%: ISASAILFILES ?= $(ISADIR)/*.sail
get_isa_model_%: ISALEMFILES ?= $(ISADIR)/*.lem
get_isa_model_%: ISAGENFILES ?= $(ISADIR)/gen/*
get_isa_model_%: ISA_INTERPCONVERT ?= $(ISADIR)/$(ISANAME)_toFromInterp2.ml
get_isa_model_%: ISADEFSFILES ?=
get_isa_model_%: FORCE
	rm -rf $(ISABUILDDIR)
	mkdir -p $(ISABUILDDIR)
	$(if $(call equal,$(BUILDISA),true),\
	  $(if $(call equal,$(CLEANDEPS),true),$(MAKE) -C $(ISADIR) clean &&)\
	  cp -a $(ISASAILFILES) $(ISABUILDDIR) &&\
	  cp -a $(ISALEMFILES) $(ISABUILDDIR) &&\
	  { [ ! -f $(ISADIR)/$(ISANAME).ml ] || cp -a $(ISADIR)/$(ISANAME).ml $(ISABUILDDIR)/$(ISANAME).ml.notstub; } &&\
	  { [ ! -f $(ISA_INTERPCONVERT) ] || cp -a $(ISA_INTERPCONVERT) $(ISABUILDDIR)/$(ISANAME)_toFromInterp2.ml.notstub; })
	cp -a src_top/generic_sail_ast_def_stub.ml $(ISABUILDDIR)/$(ISANAME).ml.stub
	{ [ ! -f src_top/$(ISANAME)_toFromInterp2.ml.stub ] || cp -a src_top/$(ISANAME)_toFromInterp2.ml.stub $(ISABUILDDIR); }
	mkdir -p $(ISABUILDDIR)/gen
	cp -a $(ISAGENFILES) $(ISABUILDDIR)/gen/
	$(if $(ISADEFSFILES), cp -a $(ISADEFSFILES) .,)
	$(MAKE) patch_isa_model_$*
CLEANDIRS += build_isa_models

patch_isa_model_%:
	echo "no patches for $*"

get_isa_model_power: ISANAME=power
get_isa_model_power: ISADIR=$(saildir)/arch/power
ifeq ($(filter PPCGEN,$(ISA_LIST)),)
  get_isa_model_power: BUILDISA=false
  RMEMSTUBS += build_isa_models/power/power.ml
  RMEMSTUBS += src_top/PPCGenTransSail.ml
endif
get_all_isa_models: get_isa_model_power

# use $(call patch,<original_file>,<path_file>) in the recipe of a rule;
# this will patch <original_file> without changing its modiffication time
# patch = modtime="$$(stat --printf '%y' $(1))" &&\
#   patch $(1) $(2) &&\
#   touch -d "$$modtime" $(1)
patch = patch $(1) $(2)

patch_isa_model_power:
# the shallow embedding generates bad code because of some typing issue
ifeq ($(filter PPCGEN,$(ISA_LIST)),)
else
	$(call patch,build_isa_models/power/power_embed.lem,patches/power_embed.lem.patch)
endif

gen_patch_isa_model_power:
	diff -au $(saildir)/arch/power/power_embed.lem build_isa_models/power/power_embed.lem > patches/power_embed.lem.patch || true

get_isa_model_aarch64: ISANAME=armV8
get_isa_model_aarch64: ISADIR=$(saildir)/arch/arm
ifeq ($(filter AArch64,$(ISA_LIST)),)
  get_isa_model_aarch64: BUILDISA=false
  RMEMSTUBS += build_isa_models/aarch64/armV8.ml
  RMEMSTUBS += src_top/AArch64HGenTransSail.ml
endif
get_all_isa_models: get_isa_model_aarch64

# TODO: Currently AArch64Gen is always stubbed out
RMEMSTUBS += src_top/AArch64GenTransSail.ml

get_isa_model_mips: ISANAME=mips
get_isa_model_mips: ISADIR=$(saildir)/arch/mips
ifeq ($(filter MIPS,$(ISA_LIST)),)
  get_isa_model_mips: BUILDISA=false
  RMEMSTUBS += build_isa_models/mips/mips.ml
  RMEMSTUBS += src_top/MIPSHGenTransSail.ml
endif
get_all_isa_models: get_isa_model_mips

get_isa_model_riscv: ISANAME=riscv
get_isa_model_riscv: ISADIR=$(riscvdir)
get_isa_model_riscv: ISASAILFILES=$(ISADIR)/model/*.sail
get_isa_model_riscv: ISALEMFILES=$(ISADIR)/generated_definitions/for-rmem/*.lem
get_isa_model_riscv: ISALEMFILES+=$(ISADIR)/handwritten_support/0.11/*.lem
get_isa_model_riscv: ISA_INTERPCONVERT=$(ISADIR)/generated_definitions/for-rmem/riscv_toFromInterp2.ml
get_isa_model_riscv: ISAGENFILES=$(ISADIR)/handwritten_support/hgen/*.hgen
get_isa_model_riscv: ISADEFSFILES=$(ISADIR)/generated_definitions/for-rmem/riscv.defs
INSTALL_DEFS_FILES += riscv.defs
CLEANFILES += riscv.defs

# By assigning a value to SAIL_DIR we force riscv to build with the
# checked-out Sail2 instead of Sail2 from opam:
get_isa_model_riscv: BUILDISATARGET=SAIL_DIR="$(realpath $(sail2dir))" riscv_rmem
ifeq ($(filter RISCV,$(ISA_LIST)),)
  get_isa_model_riscv: BUILDISA=false
  RMEMSTUBS += build_isa_models/riscv/riscv.ml
  RMEMSTUBS += src_top/RISCVHGenTransSail.ml
  RMEMSTUBS += build_isa_models/riscv/riscv_toFromInterp2.ml
endif
get_all_isa_models: get_isa_model_riscv

get_isa_model_x86: ISANAME=x86
get_isa_model_x86: ISADIR=$(saildir)/arch/x86
ifeq ($(filter X86,$(ISA_LIST)),)
  get_isa_model_x86: BUILDISA=false
  RMEMSTUBS += build_isa_models/x86/x86.ml
  RMEMSTUBS += src_top/X86HGenTransSail.ml
endif
get_all_isa_models: get_isa_model_x86

######################################################################

pp2ml:
	rm -f pp2ml.native
	$(OCAMLBUILD) -no-plugin -use-ocamlfind src_top/herd_based/pp2ml.native
.PHONY: pp2ml
get_all_deps: pp2ml
CLEANFILES += $(call add_ocaml_exts,pp2ml)

litmus2xml: get_all_deps
	rm -f litmus2xml.native
	$(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_top/litmus2xml.native $(HIGHLIGHT)
	@[ -f litmus2xml.native ]
.PHONY: litmus2xml
CLEANFILES += $(call add_ocaml_exts,litmus2xml)

######################################################################

LEM=lem

LEMFLAGS += -only_changed_output
LEMFLAGS += -wl_unused_vars ign
LEMFLAGS += -wl_pat_comp ign
LEMFLAGS += -wl_pat_exh ign
# LEMFLAGS += -wl_pat_fail ign
LEMFLAGS += -wl_comp_message ign
LEMFLAGS += -wl_rename ign

ifeq ($(filter PPCGEN,$(ISA_LIST)),)
  POWER_FILES += src_concurrency_model/isa_stubs/power/power_embed_types.lem
  POWER_FILES += src_concurrency_model/isa_stubs/power/power_embed.lem
  POWER_FILES += src_concurrency_model/isa_stubs/power/powerIsa.lem
  POWER_FILES += $(if $(call notequal,$(UI),isabelle),src_concurrency_model/isa_stubs/power/power_extras.lem)
  ISA_TOFROM_INTERP_FILES += src_concurrency_model/isa_stubs/power/power_toFromInterp.lem
else
  POWER_FILES += build_isa_models/power/power_extras_embed.lem
  POWER_FILES += build_isa_models/power/power_embed_types.lem
  POWER_FILES += build_isa_models/power/power_embed.lem
  POWER_FILES += src_concurrency_model/powerIsa.lem
  POWER_FILES += $(if $(call notequal,$(UI),isabelle),build_isa_models/power/power_extras.lem)
  ISA_TOFROM_INTERP_FILES += build_isa_models/power/power_toFromInterp.lem
endif

ifeq ($(filter AArch64,$(ISA_LIST)),)
  AARCH64_FILES += src_concurrency_model/isa_stubs/aarch64/armV8_embed_types.lem
  AARCH64_FILES += src_concurrency_model/isa_stubs/aarch64/armV8_embed.lem
  AARCH64_FILES += src_concurrency_model/isa_stubs/aarch64/aarch64Isa.lem
  AARCH64_FILES += $(if $(call notequal,$(UI),isabelle),src_concurrency_model/isa_stubs/aarch64/armV8_extras.lem)
  ISA_TOFROM_INTERP_FILES += src_concurrency_model/isa_stubs/aarch64/armV8_toFromInterp.lem
else
  AARCH64_FILES += build_isa_models/aarch64/armV8_extras_embed.lem
  AARCH64_FILES += build_isa_models/aarch64/armV8_embed_types.lem
  AARCH64_FILES += build_isa_models/aarch64/armV8_embed.lem
  AARCH64_FILES += src_concurrency_model/aarch64Isa.lem
  AARCH64_FILES += $(if $(call notequal,$(UI),isabelle),build_isa_models/aarch64/armV8_extras.lem)
  ISA_TOFROM_INTERP_FILES += build_isa_models/aarch64/armV8_toFromInterp.lem
endif

ifeq ($(filter MIPS,$(ISA_LIST)),)
  MIPS_FILES += src_concurrency_model/isa_stubs/mips/mips_embed_types.lem
  MIPS_FILES += src_concurrency_model/isa_stubs/mips/mips_embed.lem
  MIPS_FILES += src_concurrency_model/isa_stubs/mips/mipsIsa.lem
  MIPS_FILES += $(if $(call notequal,$(UI),isabelle),src_concurrency_model/isa_stubs/mips/mips_extras.lem)
  ISA_TOFROM_INTERP_FILES += src_concurrency_model/isa_stubs/mips/mips_toFromInterp.lem
else
  MIPS_FILES += build_isa_models/mips/mips_extras_embed.lem
  MIPS_FILES += build_isa_models/mips/mips_embed_types.lem
  MIPS_FILES += build_isa_models/mips/mips_embed.lem
  MIPS_FILES += src_concurrency_model/mipsIsa.lem
  MIPS_FILES += $(if $(call notequal,$(UI),isabelle),build_isa_models/mips/mips_extras.lem)
  ISA_TOFROM_INTERP_FILES += build_isa_models/mips/mips_toFromInterp.lem
endif

ifeq ($(filter RISCV,$(ISA_LIST)),)
  RISCV_FILES += src_concurrency_model/isa_stubs/riscv/riscv_types.lem
  RISCV_FILES += src_concurrency_model/isa_stubs/riscv/riscv.lem
  RISCV_FILES += src_concurrency_model/isa_stubs/riscv/riscvIsa.lem
  ISA_TOFROM_INTERP_FILES += src_concurrency_model/isa_stubs/riscv/riscv_toFromInterp.lem
else
  RISCV_FILES += build_isa_models/riscv/riscv_extras.lem
  RISCV_FILES += build_isa_models/riscv/riscv_extras_fdext.lem
  RISCV_FILES += build_isa_models/riscv/mem_metadata.lem
  RISCV_FILES += build_isa_models/riscv/riscv_types.lem
  RISCV_FILES += build_isa_models/riscv/riscv.lem
  # FIXME: using '-wl_pat_red ign' is very bad but because riscv.lem is
  # generated by shallow embedding there is not much we can do
  LEMFLAGS += -wl_pat_red ign
  RISCV_FILES += src_concurrency_model/riscvIsa.lem
  ISA_TOFROM_INTERP_FILES += src_concurrency_model/isa_stubs/riscv/riscv_toFromInterp.lem
#  ISA_TOFROM_INTERP_FILES += build_isa_models/riscv/riscv_toFromInterp.lem
endif

ifeq ($(filter X86,$(ISA_LIST)),)
  X86_FILES += src_concurrency_model/isa_stubs/x86/x86_embed_types.lem
  X86_FILES += src_concurrency_model/isa_stubs/x86/x86_embed.lem
  X86_FILES += src_concurrency_model/isa_stubs/x86/x86Isa.lem
  X86_FILES += $(if $(call notequal,$(UI),isabelle),src_concurrency_model/isa_stubs/x86/x86_extras.lem)
  ISA_TOFROM_INTERP_FILES += src_concurrency_model/isa_stubs/x86/x86_toFromInterp.lem
else
  X86_FILES += build_isa_models/x86/x86_extras_embed.lem
  X86_FILES += build_isa_models/x86/x86_embed_types.lem
  X86_FILES += build_isa_models/x86/x86_embed.lem
  X86_FILES += src_concurrency_model/x86Isa.lem
  X86_FILES += $(if $(call notequal,$(UI),isabelle),build_isa_models/x86/x86_extras.lem)
  ISA_TOFROM_INTERP_FILES += build_isa_models/x86/x86_toFromInterp.lem
endif

MACHINEFILES-PRE=\
  build_sail_shallow_embedding/sail_values.lem\
  build_sail_shallow_embedding/prompt.lem\
  build_sail2_shallow_embedding/sail2_instr_kinds.lem\
  build_sail2_shallow_embedding/sail2_values.lem\
  build_sail2_shallow_embedding/sail2_operators.lem\
  build_sail2_shallow_embedding/sail2_operators_mwords.lem\
  build_sail2_shallow_embedding/sail2_prompt_monad.lem\
  build_sail2_shallow_embedding/sail2_prompt.lem\
  build_sail2_shallow_embedding/sail2_string.lem\
  src_concurrency_model/utils.lem\
  src_concurrency_model/freshIds.lem\
  $(RISCV_FILES)\
  $(POWER_FILES)\
  $(AARCH64_FILES)\
  $(MIPS_FILES)\
  $(X86_FILES)\
  src_concurrency_model/instructionSemantics.lem\
  src_concurrency_model/exceptionTypes.lem\
  src_concurrency_model/events.lem\
  src_concurrency_model/fragments.lem\
  src_concurrency_model/elfProgMemory.lem\
  src_concurrency_model/isa.lem\
  src_concurrency_model/regUtils.lem\
  src_concurrency_model/uiTypes.lem\
  src_concurrency_model/params.lem\
  src_concurrency_model/dwarfTypes.lem\
  src_concurrency_model/instructionKindPredicates.lem\
  src_concurrency_model/candidateExecution.lem\
  src_concurrency_model/machineDefTypes.lem\
  src_concurrency_model/machineDefUI.lem\
  src_concurrency_model/machineDefPLDI11StorageSubsystem.lem\
  src_concurrency_model/machineDefFlowingStorageSubsystem.lem\
  src_concurrency_model/machineDefFlatStorageSubsystem.lem\
  src_concurrency_model/machineDefPOPStorageSubsystem.lem\
  src_concurrency_model/machineDefTSOStorageSubsystem.lem\
  src_concurrency_model/machineDefThreadSubsystemUtils.lem\
  src_concurrency_model/machineDefThreadSubsystem.lem\
  src_concurrency_model/machineDefSystem.lem\
  src_concurrency_model/machineDefTransitionUtils.lem\
  src_concurrency_model/promisingViews.lem\
  src_concurrency_model/promisingTransitions.lem\
  src_concurrency_model/promisingThread.lem\
  src_concurrency_model/promisingStorageTSS.lem\
  src_concurrency_model/promisingStorage.lem\
  src_concurrency_model/promising.lem\
  src_concurrency_model/promisingDwarf.lem\
  src_concurrency_model/promisingUI.lem\
  src_concurrency_model/sail_1_2_convert.lem

MACHINEFILES=\
  $(wildcard build_sail_interp/*.lem)\
  build_sail_shallow_embedding/deep_shallow_convert.lem\
  $(MACHINEFILES-PRE)\
  $(ISA_TOFROM_INTERP_FILES)

build_concurrency_model/make_sentinel: $(FORCECONCSENTINEL) $(MACHINEFILES)
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	$(LEM) $(LEMFLAGS) -outdir $(dir $@) -ocaml $(MACHINEFILES)
	echo '$(ISA)' > $@
CLEANDIRS += build_concurrency_model

######################################################################

MACHINEFILES-ISABELLE=\
  build_sail_interp/sail_impl_base.lem\
  $(MACHINEFILES-PRE)

build_isabelle_concurrency_model/make_sentinel: $(FORCECONCSENTINEL) $(MACHINEFILES-ISABELLE)
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	$(LEM) $(LEMFLAGS) -outdir $(dir $@) -isa $(MACHINEFILES-ISABELLE)
	echo '$(ISA)' > $@
# 	echo 'session MODEL = "LEM" + theories MachineDefTSOStorageSubsystem MachineDefSystem' > generated_isabelle/ROOT
CLEANDIRS += build_isabelle_concurrency_model

######################################################################

headers_src_concurrency_model:
	@$(foreach FILE, $(shell find src_concurrency_model/ -type f), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

headers_src_top:
	@$(foreach FILE, $(shell find src_top/ -type f -not -path "src_top/herd_based/*"), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)


headers_src_marshal_defs:
	@$(foreach FILE, $(shell find src_marshal_defs/ -type f), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

headers_src_web_interface:
	@$(foreach FILE, src_web_interface/index.html \
	     $(shell find src_web_interface/web_assets -maxdepth 1 -type f  \
             -not -path "src_web_interface/web_assets/lib/*" -and \
             -name "*.js" -or -name "*.css" -or -name "*.html"), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

headers_makefiles:
	@$(foreach FILE, Makefile myocamlbuild.ml web_interface_tests.mk, \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

# headers_scripts:
# 	@$(foreach FILE, $(shell find scripts), \
# 		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
# 	)

headers: \
headers_src_concurrency_model \
headers_src_top \
headers_src_marshal_defs \
headers_src_web_interface \
headers_makefiles
#headers_scripts \

.PHONY: \
headers_src_concurrency_model \
headers_src_top \
headers_src_marshal_defs \
headers_src_web_interface \
headers_makefiles
# headers_scripts \


######################################################################

sloc_concurrency_model: TEMPDIR=temp_sloc_concurrency_model
sloc_concurrency_model:
	$(if $(wildcard $(CONCSENTINEL)),,$(error "do 'make rmem' first"))
	@rm -rf $(TEMPDIR)
	@mkdir -p $(TEMPDIR)
	@cp $(MACHINEFILES) $(TEMPDIR)
	@for f in $(TEMPDIR)/*.lem; do mv "$$f" "$${f%.lem}.ml"; done
	@sloccount --details $(TEMPDIR) | grep -F '.ml'
	@sloccount $(TEMPDIR) | grep -F 'ml:'
	@echo "*"
	@echo "* NOTE: the .ml files above are actually .lem files that were renamed to fool sloccount"
	@echo "*"
	@rm -rf $(TEMPDIR)
.PHONY: sloc_concurrency_model

sloc_isa_models: ISAs := $(foreach d,$(wildcard build_isa_models/*),$(if $(wildcard $(d)/*.sail),$(notdir $(d))))
sloc_isa_models:
	@$(if $(ISAs),\
	  $(MAKE) --no-print-directory $(addprefix sloc_isa_model_,$(ISAs)),\
	  $(error do 'make rmem' first))
.PHONY: sloc_isa_models

sloc_isa_model_%: TEMPDIR=temp_sloc_isa_model
sloc_isa_model_%: FORCE
	$(if $(wildcard build_isa_models/$*/*.sail),,$(error "do 'make rmem' first"))
	@echo
	@echo '**** ISA model $*: ****'
	@rm -rf $(TEMPDIR)
	@mkdir -p $(TEMPDIR)
	@cp build_isa_models/$*/*.sail $(TEMPDIR)
	@for f in $(TEMPDIR)/*.sail; do mv "$$f" "$${f%.sail}.ml"; done
	@sloccount --details $(TEMPDIR) | grep ml
	@sloccount $(TEMPDIR) | grep -F 'ml:'
	@echo "*"
	@echo "* NOTE: the .ml files above are actually .sail files that were renamed to fool sloccount"
	@echo "*"
	@rm -rf $(TEMPDIR)

######################################################################

jenkins-sanity: sanity.xml
.PHONY: jenkins-sanity

sanity.xml: REGRESSIONDIR = $(REMSDIR)/litmus-tests-regression-machinery
sanity.xml: FORCE
	$(MAKE) -s -C $(REGRESSIONDIR) suite-sanity RMEMDIR=$(CURDIR) ISADRIVERS="interp shallow" TARGETS=clean-model
	$(MAKE) -s -C $(REGRESSIONDIR) suite-sanity RMEMDIR=$(CURDIR) ISADRIVERS="interp shallow"
	$(MAKE) -s -C $(REGRESSIONDIR) suite-sanity RMEMDIR=$(CURDIR) ISADRIVERS="interp shallow" TARGETS=report-junit-testcase > '$@.tmp'
	{ printf '<testsuites>\n' &&\
	  printf '  <testsuite name="sanity" tests="%d" failures="%d" timestamp="%s">\n' "$$(grep -c -F '<testcase name=' '$@.tmp')" "$$(grep -c -F '<error message="fail">' '$@.tmp')" "$$(date)" &&\
	  sed 's/^/    /' '$@.tmp' &&\
	  printf '  </testsuite>\n' &&\
	  printf '</testsuites>\n';\
	} > '$@'
	rm -rf '$@.tmp'

######################################################################

# When %.ml does not exist, myocamlbuild.ml will choose %.ml.notstub or
# %.ml.stub based on the presence of %.ml in $RMEMSTUBS
export RMEMSTUBS
