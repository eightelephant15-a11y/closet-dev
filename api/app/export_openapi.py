"""Print the OpenAPI schema (source of truth for the Dart contract tests)."""

import json

from app.main import create_app

if __name__ == "__main__":
    print(json.dumps(create_app().openapi(), indent=2, sort_keys=True))
