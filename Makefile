# gitctl — 安装与检查
PREFIX ?= /opt/homebrew
BINDIR  = $(PREFIX)/bin

.PHONY: install uninstall test

install: ## 软链接到 $(BINDIR)/gitctl
	ln -sf "$(CURDIR)/bin/gitctl" "$(BINDIR)/gitctl"
	@echo "已安装: $(BINDIR)/gitctl -> $(CURDIR)/bin/gitctl"

uninstall:
	rm -f "$(BINDIR)/gitctl"
	@echo "已卸载: $(BINDIR)/gitctl"

test: ## 语法 / bash 3.2 兼容 / 功能冒烟
	@test/smoke.sh
