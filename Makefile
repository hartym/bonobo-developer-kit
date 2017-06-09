PWD ?= $(shell pwd)
PACKAGE ?= bonobo
PACKAGES ?= bonobo bonobo-docker bonobo-sqlalchemy
IMPORT ?= $(subst -,_,$(PACKAGE))
IMPORTS ?= $(subst -,_,$(PACKAGES))
PYTHON_VERSION ?= 3.5
PYTHON_VERSIONS ?= 3.5 3.6
PYTHON_BASE ?= $(PWD)/.virtualenvs/$(PYTHON_VERSION)
PYTHON_BIN ?= $(PYTHON_BASE)/bin
PYTHON_PIP ?= $(PYTHON_BIN)/pip$(PYTHON_VERSION)
PYTHON ?= $(PYTHON_BIN)/python$(PYTHON_VERSION)
PYTEST ?= $(PYTHON_BIN)/pytest
PYTEST_OPTIONS ?= --capture=no
TWINE ?= $(PYTHON_BIN)/twine
SYSTEMPYTHON ?= $(shell which python3)
SYSTEMVIRTUALENV ?= $(shell which virtualenv)

FORMAT_TARGETS := $(addprefix format-,$(PACKAGES))
INSTALL_REQS_TARGETS := $(addprefix install-reqs-,$(PYTHON_VERSIONS))
INSTALL_TARGETS := $(addprefix install-,$(PYTHON_VERSIONS))
RELEASE_TARGETS := $(foreach p,$(PACKAGES),$(foreach v,$(PYTHON_VERSIONS),release-$p-$v))
UPDATE_TARGETS := $(addprefix update-,$(PACKAGES))
UPLOAD_TARGETS := $(addprefix upload-,$(PACKAGES))
VERSION := $(shell $(PYTHON) $(PACKAGE)/setup.py --version 2>/dev/null)

.PHONY: all clean cleanenv install release release-one $(INSTALL_TARGETS) $(INSTALL_REQS_TARGETS) $(RELEASE_TARGETS) upload upload-one $(UPLOAD_TARGETS) test builddeps

#
# Install targets
#

.PHONY: install do-install do-install-reqs $(INSTALL_TARGETS) $(INSTALL_REQS_TARGETS)

install: $(INSTALL_TARGETS)
	$(PYTHON) bin/_bdk.py init
	$(MAKE) -j2 $(INSTALL_REQS_TARGETS)

do-install: $(PYTHON_BASE)
	$(PYTHON_PIP) install -r requirements.txt

do-install-reqs: $(PYTHON_BASE)
	$(PYTHON_PIP) install -r .requirements.local.txt

$(PYTHON_BASE):
	$(SYSTEMVIRTUALENV) -p python$(PYTHON_VERSION) $@
	$(PYTHON) -m ensurepip --upgrade

$(INSTALL_TARGETS): install-%:
	PYTHON_VERSION=$* $(MAKE) do-install

$(INSTALL_REQS_TARGETS): install-reqs-%:
	PYTHON_VERSION=$* $(MAKE) do-install-reqs

#
# Format targets
#

format: $(FORMAT_TARGETS)

do-format:
	cd $(PACKAGE); QUICK=1 PYTHON=$(PYTHON) make format;

$(FORMAT_TARGETS): format-%:
	PYTHON_VERSION=3.6 PACKAGE=$* $(MAKE) do-format

#
# Update targets
#

update: $(UPDATE_TARGETS)

do-update:
	cd $(PACKAGE); rm requirements*.txt; edgy-project update;
	$(MAKE) do-format

$(UPDATE_TARGETS): update-%:
	PYTHON_VERSION=3.6 PACKAGE=$* $(MAKE) do-update



#
# Test targets
#

.PHONY: test

test:
	$(PYTEST) $(PYTEST_OPTIONS) bonobo/tests bonobo-sqlalchemy/tests --cov=bonobo --cov=bonobo_sqlalchemy --cov-report html

#
# Cleanup targets
#

.PHONY: clean cleanall

clean:
	rm -rf output

cleanall: clean
	rm -rf .virtualenvs

#
# Release/upload targets
#

.PHONY: builddeps release do-release $(RELEASE_TARGETS) upload do-upload $(UPLOAD_TARGETS)

release: $(RELEASE_TARGETS)

upload: $(UPLOAD_TARGETS)

do-release: output
	$(eval TMP := $(shell mktemp -d))
	@echo "Cooking $(PACKAGE) $(VERSION) release (in $(TMP))"
	@(cd $(PACKAGE); git rev-parse $(VERSION))
	@(cd $(PACKAGE); git archive `git rev-parse $(VERSION)`) | tar xf - -C $(TMP)
	@(cd output; $(PYTHON) $(TMP)/setup.py sdist bdist_egg bdist_wheel > /dev/null)
	@rm -rf $(TMP)

do-upload:
	twine upload --skip-existing output/dist/$(IMPORT)-$(VERSION)*

$(RELEASE_TARGETS): release-%:
	-$(MAKE) do-release `echo $* | sed 's/^\(.*\)-\(3\.[0-9]\)$$/PACKAGE=\1 PYTHON_VERSION=\2/g'`

$(UPLOAD_TARGETS): upload-%:
	-$(MAKE) do-upload PACKAGE=$*

builddeps:
	$(PYTHON_PIP) install -U pip wheel twine

output:
	mkdir -p output
