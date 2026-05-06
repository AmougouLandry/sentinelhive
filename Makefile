# ============================================================
# SentinelHive — Makefile
# Common operations wrapped in simple commands.
# Usage: make <target>
# ============================================================

.PHONY: help up down restart logs ps clean status

help: ## Show this help message
	@echo "SentinelHive — available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start all services
	docker compose up -d

down: ## Stop and remove all services
	docker compose down

restart: ## Restart all services
	docker compose restart

logs: ## Tail logs from all services
	docker compose logs -f --tail=100

ps: ## Show running services
	docker compose ps

status: ## Show service status with formatted output
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

clean: ## Remove containers, volumes, and orphans (DESTRUCTIVE)
	docker compose down -v --remove-orphans
