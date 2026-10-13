.PHONY: ios-flavors-setup setup api-test api-lint app-test app-lint app-gen up down run-mock test lint openapi

setup:
	cd api && python3.12 -m venv .venv && . .venv/bin/activate && pip install -e ".[dev]"
	cd app && flutter pub get && flutter gen-l10n && dart format lib/l10n/gen && dart run build_runner build -d
	pre-commit install || true

up:
	docker compose up --build -d
down:
	docker compose down

api-test:
	cd api && . .venv/bin/activate && pytest -q
api-lint:
	cd api && . .venv/bin/activate && ruff check . && ruff format --check . && mypy app
app-gen:
	cd app && flutter gen-l10n && dart run build_runner build -d
app-test:
	cd app && flutter test
app-lint:
	cd app && dart format --set-exit-if-changed lib test integration_test && flutter analyze

run-mock:  ## app in mock mode, no cloud needed
	cd app && flutter run --flavor dev -t lib/main_dev.dart --dart-define=USE_MOCK=true

openapi:
	cd api && . .venv/bin/activate && python -m app.export_openapi > ../docs/openapi.json

test: api-test app-test
lint: api-lint app-lint

# ---- flavor x platform targets -----------------------------------------------------------
# run-<flavor>-<android|ios>        run on a connected device/emulator (mock API by default)
# apk-<flavor>                      Android APK (debug)   | apk-release-<flavor>
# ios-<flavor>                      iOS build, NO code signing (CI-safe) | ipa-<flavor> signed IPA
FLAVORS := dev staging prod
MOCK ?= true

$(foreach f,$(FLAVORS),$(eval run-$(f)-android: ; cd app && flutter run --flavor $(f) -t lib/main_$(f).dart --dart-define=USE_MOCK=$(MOCK)))
$(foreach f,$(FLAVORS),$(eval run-$(f)-ios: ; cd app && flutter run --flavor $(f) -t lib/main_$(f).dart --dart-define=USE_MOCK=$(MOCK)))
$(foreach f,$(FLAVORS),$(eval apk-$(f): ; cd app && flutter build apk --debug --flavor $(f) -t lib/main_$(f).dart --dart-define=USE_MOCK=$(MOCK)))
$(foreach f,$(FLAVORS),$(eval apk-release-$(f): ; cd app && flutter build apk --release --flavor $(f) -t lib/main_$(f).dart --dart-define=USE_MOCK=$(MOCK)))
$(foreach f,$(FLAVORS),$(eval ios-$(f): ; cd app && flutter build ios --release --no-codesign --flavor $(f) -t lib/main_$(f).dart --dart-define=USE_MOCK=$(MOCK)))
$(foreach f,$(FLAVORS),$(eval ipa-$(f): ; cd app && flutter build ipa --flavor $(f) -t lib/main_$(f).dart --dart-define=USE_MOCK=false))

ios-flavors-setup:  ## re-apply iOS flavor config to the Xcode project (idempotent)
	cd app/ios && ruby ../tool/setup_ios_flavors.rb
	python3 app/tool/make_flavor_icons.py
	python3 app/tool/gen_ios_strings.py
