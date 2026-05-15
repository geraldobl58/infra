.PHONY: help setup start stop restart destroy status logs k9s grafana prometheus argocd secrets helm-lint helm-template apply-argocd

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
	@kubectl logs -n $(or $(NAMESPACE),crivo-develop) -l app.kubernetes.io/name=$(SERVICE) --tail=100 -f

secrets: ## Aplica secrets das apps em um ambiente. Uso: make secrets ENV=develop
	@if [ -z "$(ENV)" ]; then \
		echo "$(YELLOW)⚠️  Especifique ENV. Exemplo: make secrets ENV=develop$(RESET)"; \
		exit 1; \
	fi
	@./scripts/create-app-secrets.sh $(ENV)

helm-lint: ## Valida o chart crivo-app contra os values de cada app/ambiente
	@for app in crivo-auth crivo-be crivo-fe; do \
		for env in develop prod; do \
			echo "$(BLUE)→ helm lint $$app/$$env$(RESET)"; \
			helm lint helm/crivo-app \
				-f helm/crivo-app/apps/$$app/values.yaml \
				-f helm/crivo-app/apps/$$app/values-$$env.yaml || exit 1; \
		done; \
	done
	@echo "$(GREEN)✅ Lint OK$(RESET)"

helm-template: ## Renderiza chart. Uso: make helm-template APP=crivo-be ENV=develop
	@helm template $(APP) helm/crivo-app \
		-f helm/crivo-app/apps/$(APP)/values.yaml \
		-f helm/crivo-app/apps/$(APP)/values-$(ENV).yaml

apply-argocd: ## (Re)aplica AppProjects e ApplicationSet no cluster
	@kubectl apply -f argocd/projects/crivo-environments.yaml
	@kubectl apply -f argocd/applicationsets/crivo-apps.yaml
	@echo "$(GREEN)✅ ArgoCD: projects + applicationset aplicados$(RESET)"

k9s: ## Abre k9s para gerenciamento visual
	@k9s

grafana: ## Abre o Grafana no browser
	@open http://grafana.devops.local

prometheus: ## Abre o Prometheus no browser
	@open http://prometheus.devops.local

argocd: ## Abre o ArgoCD no browser
	@open http://argocd.devops.local

.DEFAULT_GOAL := help
