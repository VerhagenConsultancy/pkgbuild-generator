PROJECT_NAME?=UNKNOWN
SOURCE_DIR?=../$(PROJECT_NAME)
BUILD_DIR?=../build_package
PREFIX?=../package
PKG_IN?=../PKGBUILD.in
GITCHANGELOG_RC?="../.gitchangelog.rc"

PKGREL?=1
EPOCH?=

CURDIR:=$(shell pwd)

CHANGELOG:=$(PROJECT_NAME).changelog
CHANGELOG_TEMP_TEMPLATE:=$(CHANGELOG).tmp
CHANGELOG_TEMP:=$(shell mktemp --dry-run $(CHANGELOG_TEMP_TEMPLATE).XXX)

PKG_FILE:=PKGBUILD
PKG_TEMP_TEMPLATE:=$(PKG_FILE).tmp
PKG_TEMP:=$(shell mktemp --dry-run $(PKG_TEMP_TEMPLATE).XXX)

SRC_INFO_FILE_NAME:=.SRCINFO
SRC_INFO_FILE:=$(BUILD_DIR)/$(SRC_INFO_FILE_NAME)

COMMIT:=$(shell git -C $(SOURCE_DIR) rev-parse HEAD)
SHORT_COMMIT:=$(shell git -C $(SOURCE_DIR) rev-parse --short HEAD)
COMMIT_NUMBER:=$(shell git -C $(SOURCE_DIR) rev-list --count HEAD)
VERSION_DESCRIBE:=$(shell git -C $(SOURCE_DIR) describe --tags --long "--match=*.*.*" 2>/dev/null || printf "r%s.%s" "$(COMMIT_NUMBER)" "$(SHORT_COMMIT)")
VERSION?=$(subst -,_,$(VERSION_DESCRIBE))

all: build

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(CHANGELOG): $(BUILD_DIR)
	cd "${SOURCE_DIR}" && GITCHANGELOG_CONFIG_FILENAME=$(GITCHANGELOG_RC) gitchangelog > "$(BUILD_DIR)/$(CHANGELOG_TEMP)"
	sed -i "s/@UNRELEASED@/$(VERSION)/g" $(BUILD_DIR)/$(CHANGELOG_TEMP)
	mv $(BUILD_DIR)/$(CHANGELOG_TEMP) $(BUILD_DIR)/$(CHANGELOG)

$(BUILD_DIR)/$(PKG_FILE): $(BUILD_DIR) $(PKG_IN)
	cp $(PKG_IN) $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@PACKAGE@/$(PROJECT_NAME)/g" $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@UNRELEASED@/$(VERSION)/g" $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@VERSION@/$(VERSION)/g" $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@GIT_REF@/$(COMMIT)/g" $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@CHANGELOG@/$(CHANGELOG)/g" $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@PKGREL@/$(PKGREL)/g" $(BUILD_DIR)/$(PKG_TEMP)
	sed -i "s/@EPOCH@/$(EPOCH)/g" $(BUILD_DIR)/$(PKG_TEMP)
	mv $(BUILD_DIR)/$(PKG_TEMP) $(BUILD_DIR)/$(PKG_FILE)

pkgbuild:: $(BUILD_DIR)/$(PKG_FILE) $(BUILD_DIR)/$(CHANGELOG)

$(SRC_INFO_FILE): $(BUILD_DIR)/$(PKG_FILE)
	cd $(BUILD_DIR) && makepkg --printsrcinfo > $(SRC_INFO_FILE_NAME)

prepare: pkgbuild $(SRC_INFO_FILE)

build: prepare
	cd $(BUILD_DIR) && makepkg --noconfirm --needed --syncdeps --force

$(PREFIX):
	mkdir -p $(PREFIX)

install: $(PREFIX)
	cp $(BUILD_DIR)/$(SRC_INFO_FILE_NAME) $(PREFIX)/
	cp $(BUILD_DIR)/$(PKG_FILE) $(PREFIX)/
	cp $(BUILD_DIR)/$(CHANGELOG) $(PREFIX)/

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PREFIX)

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

.PHONY: prepare-build-dir prepare-version prepare-commit pkgbuild build clean all
