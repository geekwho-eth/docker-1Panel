SHELL := /bin/bash

# Defaults (override via: make build OS=ubuntu VERSION=2.0.16)
OS ?= ubuntu
VERSION ?= 2.0.16
PLATFORMS ?= linux/amd64,linux/arm64
IMAGE_REPO ?= caijiamx/1panel
IMAGE_TAG_PREFIX ?= dood
TMP_DIR := .docker-tmp
BUILDER_NAME ?= 1panel-builder
ONEPANEL_TYPE ?= pro
IMAGE_TAG ?=

# --- 根据 ONEPANEL_TYPE 的值来设置其他变量 ---
ifeq ($(ONEPANEL_TYPE),cn)
	IMAGE_TAG := -cn
	HACK_DIR := hack_cn
else
	IMAGE_TAG :=
	HACK_DIR := hack
endif

# Helper: compute current arch's platform (for --load)
CURRENT_PLATFORM := $(shell uname -m | sed 's/arm64/linux\/arm64/;s/x86_64/linux\/amd64/')

.PHONY: help builder prepare build buildx push load matrix-push clean login

help: ## 列出可用命令与说明
	@echo "用法: make <target> [OS=ubuntu|centos|alpine] [VERSION=2.0.0~2.0.16] [PLATFORMS=linux/amd64,linux/arm64] [IMAGE_REPO=...] [IMAGE_TAG_PREFIX=dood]"
	@echo
	@echo "可用目标:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo
	@echo "参数（默认值 / 当前值）:"
	@printf "  OS                default: ubuntu                         current: %s\n" "$(OS)"
	@printf "  VERSION           default: 2.0.16                         current: %s\n" "$(VERSION)"
	@printf "  PLATFORMS         default: linux/amd64,linux/arm64        current: %s\n" "$(PLATFORMS)"
	@printf "  IMAGE_REPO        default: caijiamx/1panel                current: %s\n" "$(IMAGE_REPO)"
	@printf "  IMAGE_TAG_PREFIX  default: dood                           current: %s\n" "$(IMAGE_TAG_PREFIX)"
	@printf "  CURRENT_PLATFORM  auto-detected                           %s\n" "$(CURRENT_PLATFORM)"
	@echo
	@echo "示例:"
	@echo "  make builder"
	@echo "  make load OS=alpine VERSION=2.0.16"
	@echo "  make push OS=centos VERSION=2.0.0"
	@echo "  make build OS=ubuntu VERSION=2.0.16 PLATFORMS=linux/arm64 ONEPANEL_TYPE=pro"
	@echo "  make matrix-push"

builder: ## 初始化 QEMU/binfmt 与 buildx
	# Enable binfmt for cross-arch builds
	docker run --privileged --rm tonistiigi/binfmt --install all
	# Create and bootstrap a buildx builder (ignore error if exists)
	- docker buildx create --name $(BUILDER_NAME) --use
	docker buildx inspect --bootstrap

prepare: ## 复制并替换 Dockerfile 版本变量
	@mkdir -p $(TMP_DIR)
	@cp $(OS)/Dockerfile $(TMP_DIR)/Dockerfile
	# macOS uses BSD sed; Linux uses GNU sed
	@if [ "$$(uname)" = "Darwin" ]; then \
		sed -i '' 's/{%OnePanel_Version%}/$(VERSION)/g' $(TMP_DIR)/Dockerfile; \
	else \
		sed -i 's/{%OnePanel_Version%}/$(VERSION)/g' $(TMP_DIR)/Dockerfile; \
	fi
	sed -i 's/{%OnePanel_Type%}/$(HACK_DIR)/g' $(TMP_DIR)/Dockerfile

build: prepare ## 单架构本地构建（不推送）
	docker build --progress=plain \
		-f $(TMP_DIR)/Dockerfile \
		-t $(IMAGE_REPO):$(IMAGE_TAG_PREFIX)-$(VERSION)-$(OS)$(IMAGE_TAG) \
		.

buildx: prepare ## 多架构构建（不推送）
	docker buildx build \
		--platform $(PLATFORMS) \
		-f $(TMP_DIR)/Dockerfile \
		-t $(IMAGE_REPO):$(IMAGE_TAG_PREFIX)-$(VERSION)-$(OS)$(IMAGE_TAG) \
		.

push: prepare ## 多架构构建并推送
	docker buildx build \
		--platform $(PLATFORMS) \
		-f $(TMP_DIR)/Dockerfile \
		-t $(IMAGE_REPO):$(IMAGE_TAG_PREFIX)-$(VERSION)-$(OS)$(IMAGE_TAG) \
		--push \
		.

# Build only for current machine arch and load image into local docker (fast local test)
load: prepare ## 仅当前架构构建并加载到本机
	docker buildx build \
		--platform $(CURRENT_PLATFORM) \
		-f $(TMP_DIR)/Dockerfile \
		-t $(IMAGE_REPO):$(IMAGE_TAG_PREFIX)-$(VERSION)-$(OS)$(IMAGE_TAG) \
		--load \
		.

# Local matrix push for OS x versions (same as CI matrix). Adjust as needed.
matrix-push: builder ## 循环构建并推送 OS×版本 矩阵
	@versions="2.0.0 2.0.1 2.0.2 2.0.3 2.0.4 2.0.5 2.0.6 2.0.7 2.0.8 2.0.9 2.0.10 2.0.11 2.0.12 2.0.13 2.0.14 2.0.15 2.0.16"; \
	for os in ubuntu centos alpine; do \
	  for v in $$versions; do \
	    echo "==> Building $$os $$v"; \
	    $(MAKE) push OS=$$os VERSION=$$v; \
	  done; \
	done

clean: ## 清理临时目录
	rm -rf $(TMP_DIR)

# Optional: non-interactive login via env variables (use at your own risk)
login: ## 使用环境变量进行 DockerHub 登录
	if [ -z "$$DOCKERHUB_USERNAME" ] || [ -z "$$DOCKERHUB_TOKEN" ]; then \
	  echo "Please export DOCKERHUB_USERNAME and DOCKERHUB_TOKEN, or run 'docker login' manually."; \
	  exit 1; \
	fi
	echo "$$DOCKERHUB_TOKEN" | docker login -u "$$DOCKERHUB_USERNAME" --password-stdin
