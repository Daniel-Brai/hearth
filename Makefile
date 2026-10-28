.DEFAULT_GOAL := help

.PHONY: help setup seed install-deps clean dev dev.api dev.api.observe dev.web observe observe.down gen.api format lint test coverage check up up.dev down k8s.lint k8s.render k8s.apply

# Lists every target with the first sentence of the comment above it
help:
	@awk '/^# / { doc = doc " " substr($$0, 3); next } \
	/^[a-z][a-z0-9.-]*:/ { name = $$1; sub(/:.*/, "", name); \
	  if (doc != "") { sub(/^ /, "", doc); sub(/\. .*/, ".", doc); printf "  %-14s %s\n", name, doc } \
	  doc = ""; next } \
	{ doc = "" }' $(MAKEFILE_LIST)

# Readies a fresh checkout, installing dependencies and creating the database
setup: install-deps
	mix setup

# Adds local test data for moderation, needing an account named by SEED_OWNER (default danielbrai)
seed:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	for key in $$(grep -oE '^[A-Z_]+=$$' .env 2>/dev/null | tr -d =); do unset $$key; done; \
	cd apps/hearth && mix run priv/repo/seeds.exs

# Installs the tools in .tool-versions through asdf or mise, then both apps' dependencies
install-deps:
	@tools=$$(cut -d' ' -f1 .tool-versions); \
	if command -v asdf >/dev/null 2>&1; then for tool in $$tools; do asdf install $$tool; done; \
	elif command -v mise >/dev/null 2>&1; then mise install $$tools; fi
	@command -v pnpm >/dev/null 2>&1 || corepack enable pnpm
	mix local.hex --if-missing --force
	mix local.rebar --if-missing --force
	mix deps.get
	cd web && pnpm install --frozen-lockfile

# Removes build and test output but keeps dependencies
clean:
	rm -rf _build cover apps/*/cover erl_crash.dump
	rm -rf apps/hearth_web/priv/static/assets apps/hearth_web/priv/static/cache_manifest.json
	cd web && rm -rf build dist .react-router node_modules/.vite coverage

# Runs the API and the web app together
dev:
	@trap 'kill 0' INT TERM EXIT; \
	$(MAKE) --no-print-directory dev.api & \
	$(MAKE) --no-print-directory dev.web & \
	wait

# Runs the API with the keys in .env, where blank keys keep their development defaults
dev.api:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	for key in $$(grep -oE '^[A-Z_]+=$$' .env 2>/dev/null | tr -d =); do unset $$key; done; \
	$(OBSERVE_ENV) mix phx.server

# Runs the API sending traces, logs and dashboards to the local Grafana that make observe starts
dev.api.observe:
	@$(MAKE) --no-print-directory dev.api OBSERVE_ENV="LOG_FILE=$(CURDIR)/tmp/log/hearth.jsonl OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 GRAFANA_HOST=http://localhost:3000 GRAFANA_USERNAME=admin GRAFANA_PASSWORD=admin"

# Runs the web app against the local API
dev.web:
	cd web && VITE_API_URL=http://localhost:4000 pnpm dev --port 5174 --strictPort

# Writes the API's OpenAPI file and regenerates the web app's client from it
gen.api:
	cd apps/hearth_web && mix api.spec
	cd web && pnpm gen:api

# Formats the Elixir code and the web app in place
format:
	mix format
	cd web && pnpm format

# Lints both apps with Credo and oxlint
lint:
	mix credo --strict
	cd web && pnpm lint

# Runs every test in both apps
test:
	mix test
	cd web && pnpm test

# Reports Elixir coverage, failing under the minimum in coveralls.json
coverage:
	mix coveralls.html --umbrella

# Runs everything CI checks
check:
	mix format --check-formatted
	mix compile --warnings-as-errors --force
	mix credo --strict
	mix cmd mix sobelow --skip --exit low
	mix test
	cd web && pnpm check

COMPOSE = docker compose --env-file .env -f infra/compose.yml

# Starts the whole stack in Docker behind Caddy, reading .env
up:
	$(COMPOSE) up --build --detach

# Starts the stack with Mailpit catching every email at http://localhost:8025
up.dev:
	$(COMPOSE) -f infra/compose.dev.yml up --build --detach

# Starts Grafana with Prometheus, Tempo and Loki at http://localhost:3000
observe:
	mkdir -p tmp/log
	docker compose -f infra/compose.observe.yml up --detach

# Stops the local Grafana and keeps what it collected
observe.down:
	docker compose -f infra/compose.observe.yml down

# Stops the stack and keeps its volumes
down:
	$(COMPOSE) -f infra/compose.dev.yml down

# ENV picks values.<ENV>.yaml, either staging or production
ENV ?= staging
NAMESPACE ?= hearth
RELEASE ?= hearth
CHART := infra/k8s/hearth
HELM_VALUES := -f $(CHART)/values.yaml -f $(CHART)/values.$(ENV).yaml

# Lints the Helm chart with every environment's values
k8s.lint:
	helm lint $(CHART) -f $(CHART)/values.staging.yaml
	helm lint $(CHART) -f $(CHART)/values.production.yaml

# Prints the manifests ENV would apply
k8s.render:
	helm template $(RELEASE) $(CHART) --namespace $(NAMESPACE) $(HELM_VALUES)

# Installs or upgrades ENV in the current kubectl context, rolling back if pods never get ready
k8s.apply:
	helm upgrade --install $(RELEASE) $(CHART) --namespace $(NAMESPACE) --create-namespace \
	  $(HELM_VALUES) --atomic --wait --timeout 10m
