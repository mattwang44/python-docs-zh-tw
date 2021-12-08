# Makefile for Chinese (Taiwan) Python Documentation
#
# Here is what you can do:
#
# - make  # Automatically build an html local version
# - make todo  # To list remaining tasks
# - make merge  # To merge pot from upstream
# - make fuzzy  # To find fuzzy strings
# - make progress  # To compute current progression
# - make upgrade_venv  # To upgrade the venv that compiles the doc
#
# Modes are: autobuild-stable, autobuild-dev, and autobuild-html,
# documented in gen/src/3.6/Doc/Makefile as we're only delegating the
# real work to the Python Doc Makefile.
#
# Credits: Python Documentation French Translation Team (https://github.com/python/python-docs-fr)

CPYTHON_CLONE := ../cpython
SPHINX_CONF := $(CPYTHON_CLONE)/Doc/conf.py
LANGUAGE := zh_TW
LOCALE_DIR := $(CPYTHON_CLONE)/Doc/locales
LC_MESSAGES := $(LOCALE_DIR)/$(LANGUAGE)/LC_MESSAGES
VENV := $(CPYTHON_CLONE)/.venvs/python-docs-i18n/
PYTHON := $(shell which python3)
MODE := $(or $(MODE), autobuild-dev-html)
BRANCH := $(or $(VERSION), $(shell git describe --contains --all HEAD))
JOBS := 4

UNAME := $(shell uname)
ifeq ($(UNAME),Darwin)
    $(shell brew list coreutils &>/dev/null || brew install -q coreutils)
    CP_CMD := gcp
else
    CP_CMD := cp
endif

.PHONY: all
all: $(VENV)/bin/sphinx-build clone
	@mkdir -p $(LC_MESSAGES)
	$(CP_CMD) -uv --parents *.po */*.po $(LC_MESSAGES)
	@. $(VENV)/bin/activate; $(MAKE) -C $(CPYTHON_CLONE)/Doc/ \
	  SPHINXOPTS=' \
	    -j$(JOBS) \
	    -D locale_dirs=$(LOCALE_DIR) \
	    -D language=$(LANGUAGE) \
	    -D gettext_compact=0' \
	  $(MODE)


clone:
	@git clone --depth 1 --no-single-branch https://github.com/python/cpython.git $(CPYTHON_CLONE)  || echo "cpython exists"
	@cd $(CPYTHON_CLONE) && git checkout -q $(BRANCH) && git pull -q


$(VENV)/bin/activate:
	@mkdir -p $(VENV)
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/python3 -m pip install --upgrade pip


$(VENV)/bin/sphinx-build: $(VENV)/bin/activate
	. $(VENV)/bin/activate; python3 -m pip install sphinx python-docs-theme blurb


.PHONY: upgrade_venv
upgrade_venv: $(VENV)/bin/activate
	. $(VENV)/bin/activate; python3 -m pip install --upgrade sphinx python-docs-theme blurb


.PHONY: progress
progress:
	@python3 -c 'import sys; print("{:.1%}".format(int(sys.argv[1]) / int(sys.argv[2])))'  \
	$(shell msgcat *.po */*.po | msgattrib --translated | grep -c '^msgid') \
	$(shell msgcat *.po */*.po | grep -c '^msgid')


.PHONY: todo
todo:
	for file in *.po */*.po; do echo $$(msgattrib --untranslated $$file | grep ^msgid | sed 1d | wc -l ) $$file; done | grep -v ^0 | sort -gr


.PHONY: merge
merge: upgrade_venv
ifneq "$(shell cd $(CPYTHON_CLONE) 2>/dev/null && git describe --contains --all HEAD)" "$(BRANCH)"
	$(error "You're merging from a different branch")
endif
	(cd $(CPYTHON_CLONE)/Doc; rm -f build/NEWS)
	(cd $(CPYTHON_CLONE)/Doc; $(VENV)/bin/sphinx-build -Q -b gettext -D gettext_compact=0 . $(LOCALE_DIR)/pot/)
	find $(LOCALE_DIR)/pot/ -name '*.pot' |\
	    while read -r POT;\
	    do\
	        PO="./$$(echo "$$POT" | sed "s#$(LOCALE_DIR)/pot/##; s#\.pot\$$#.po#")";\
	        mkdir -p "$$(dirname "$$PO")";\
	        if [ -f "$$PO" ];\
	        then\
	            case "$$POT" in\
	            *whatsnew*) msgmerge --lang=$(LANGUAGE) --backup=off --force-po --no-fuzzy-matching -U "$$PO" "$$POT" ;;\
	            *)          msgmerge --lang=$(LANGUAGE) --backup=off --force-po -U "$$PO" "$$POT" ;;\
	            esac\
	        else\
	            msgcat --lang=$(LANGUAGE) -o "$$PO" "$$POT";\
	        fi\
	    done


.PHONY: update_txconfig
update_txconfig:
	curl -L https://rawgit.com/python-doc-ja/cpython-doc-catalog/catalog-$(BRANCH)/Doc/locales/.tx/config |\
		grep --invert-match '^file_filter = *' |\
		sed -e 's/source_file = pot\/\(.*\)\.pot/trans.zh_TW = \1.po/' |\
		sed -n 'w .tx/config'


.PHONY: fuzzy
fuzzy:
	for file in *.po */*.po; do echo $$(msgattrib --only-fuzzy --no-obsolete "$$file" | grep -c '#, fuzzy') $$file; done | grep -v ^0 | sort -gr

.PHONY: clean
clean:
	find $(LC_MESSAGES) -name '*.mo' -delete
	$(MAKE) -C $(CPYTHON_CLONE)/Doc/ clean
