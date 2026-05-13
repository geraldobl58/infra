.PHONY: help setup start stop restart destroy status logs k9s grafana prometheus argocd

# Cores
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

help: ## Mostra este menu de ajuda
	@echo "$(BLUE)🥷 DevOps Lab Ninja - Comandos$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)💡 Dica: Use 'make' na raiz do projeto para setup/status/destroy$(RESET)"

setup: ## Setup completo (cluster + ArgoCD + observabilidade + apps)
	@echo "$(GREEN)🚀 Iniciando setup do Lab Ninja...$(RESET)"
	@chmod +x setup.sh
	@./setup.sh

start: ## Inicia o cluster (se estiver parado)
	@echo "$(GREEN)▶️  Iniciando cluster...$(RESET)"
	@k3d cluster start devops-lab
	@echo "$(GREEN)✅ Cluster iniciado$(RESET)"

stop: ## Para o cluster (mantém dados)
	@echo "$(YELLOW)⏸️  Parando cluster...$(RESET)"
	@k3d cluster stop devops-lab
	@echo "$(YELLOW)✅ Cluster parado$(RESET)"

restart: stop start ## Reinicia o cluster

destroy: ## Destroi tudo (interativo com confirmação)
	@echo "$(RED)🗑️  Destroy completo do Lab...$(RESET)"
	@chmod +x destroy.sh
	@./destroy.sh

status: ## Mostra status completo do cluster e aplicações
	@chmod +x status.sh
	@./status.sh

logs: ## Ver logs de um serviço. Uso: make logs SERVICE=crivo-be NAMESPACE=crivo-develop
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(YELLOW)⚠️  Especifique o SERVICE. Exemplo: make logs SERVICE=crivo-be NAMESPACE=crivo-develop$(RESET)"; \
		exit 1; \
	fi
	@kubectl logs -n $(or $(NAMESPACE),crivo-develop) -l app=$(SERVICE) --tail=100 -f

k9s: ## Abre k9s para gerenciamento visual
	@k9s

grafana: ## Abre o Grafana no browser
	@open http://grafana.devops.local

prometheus: ## Abre o Prometheus no browser
	@open http://prometheus.devops.local

argocd: ## Abre o ArgoCD no browser
	@open http://argocd.devops.local

.DEFAULT_GOAL := help
