.PHONY: help setup start stop restart destroy status logs k9s grafana prometheus argocd

# Cores
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

help: ## Mostra este menu de ajuda
	@echo "$(BLUE)🥷 Nexo CloudLab Ninja - Comandos$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)💡 Dica: Use 'make' na raiz do projeto para setup/status/destroy$(RESET)"

setup: ## Setup completo (cluster + ArgoCD + observabilidade + apps)
	@echo "$(GREEN)🚀 Iniciando setup do CloudLab Ninja...$(RESET)"
	@chmod +x setup.sh
	@./setup.sh

start: ## Inicia o cluster (se estiver parado)
	@echo "$(GREEN)▶️  Iniciando cluster...$(RESET)"
	@k3d cluster start nexo-local
	@echo "$(GREEN)✅ Cluster iniciado$(RESET)"

stop: ## Para o cluster (mantém dados)
	@echo "$(YELLOW)⏸️  Parando cluster...$(RESET)"
	@k3d cluster stop nexo-local
	@echo "$(YELLOW)✅ Cluster parado$(RESET)"

restart: stop start ## Reinicia o cluster

destroy: ## Destroi tudo (interativo com confirmação)
	@echo "$(RED)🗑️  Destroy completo do CloudLab...$(RESET)"
	@chmod +x destroy.sh
	@./destroy.sh

status: ## Mostra status completo do cluster e aplicações
	@chmod +x status.sh
	@./status.sh

logs: ## Ver logs de um serviço. Uso: make logs SERVICE=nexo-be NAMESPACE=nexo-develop
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(YELLOW)⚠️  Especifique o SERVICE. Exemplo: make logs SERVICE=nexo-be NAMESPACE=nexo-develop$(RESET)"; \
		exit 1; \
	fi
	@kubectl logs -n $(or $(NAMESPACE),nexo-develop) -l app=$(SERVICE) --tail=100 -f

k9s: ## Abre k9s para gerenciamento visual
	@k9s

grafana: ## Abre o Grafana no browser
	@open http://grafana.nexo.local

prometheus: ## Abre o Prometheus no browser
	@open http://prometheus.nexo.local

argocd: ## Abre o ArgoCD no browser
	@open http://argocd.nexo.local

.DEFAULT_GOAL := help
