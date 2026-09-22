# Targets used in CI and locally. If a check runs in CI it runs here too,
# so failures are reproducible without pushing.

CHART   := charts/service
VALUES  := $(wildcard values/*-prod.yaml values/*-staging.yaml)
NS      ?= prod

.PHONY: help lint validate render test install diff

help:
	@grep -E '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "};{printf "  %-12s %s\n", $$1, $$2}'

lint: ## helm lint against every values file, not just defaults
	helm lint $(CHART)
	@for v in $(VALUES); do echo "--- $$v"; helm lint $(CHART) -f $$v || exit 1; done

validate: ## render and check against the Kubernetes API schema
	@for v in $(VALUES); do \
	  echo "--- $$v"; \
	  helm template $$(basename $$v .yaml) $(CHART) -f $$v \
	    | kubeconform -strict -summary -ignore-missing-schemas || exit 1; \
	done

render: ## write rendered manifests to rendered/ for review
	@mkdir -p rendered
	@for v in $(VALUES); do \
	  helm template $$(basename $$v .yaml) $(CHART) -f $$v > rendered/$$(basename $$v); \
	done
	@echo "rendered/ written"

diff: ## show what a chart change does to every environment
	@git stash -q && $(MAKE) render && mv rendered rendered-before && \
	 git stash pop -q && $(MAKE) render && \
	 diff -ru rendered-before rendered || true; rm -rf rendered-before

test: ## helm test an installed release
	helm test $(RELEASE) -n $(NS) --logs

install: ## install every service into prod and staging
	helm upgrade --install orders    $(CHART) -f values/orders-prod.yaml    -n prod --atomic --wait
	helm upgrade --install payments  $(CHART) -f values/payments-prod.yaml  -n prod --atomic --wait
	helm upgrade --install shipments $(CHART) -f values/shipments-prod.yaml -n prod --atomic --wait
	helm upgrade --install orders    $(CHART) -f values/orders-staging.yaml -n staging --atomic --wait
