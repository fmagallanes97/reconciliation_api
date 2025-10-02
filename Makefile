.PHONY: setup build run down logs shell migrate reset reconciliation_audit open-adminer

setup:
	docker compose run --rm app mix deps.get
	docker compose run --rm app mix ecto.create
	docker compose run --rm app mix ecto.migrate

build:
	docker compose build

run:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose run --rm app sh

migrate:
	docker compose run --rm app mix ecto.migrate

reset:
	docker compose run --rm app mix ecto.drop
	make setup

reconciliation_audit:
	docker compose exec app mix reconciliation_audit

open-adminer:
	@open http://localhost:8080 || xdg-open http://localhost:8080 || start http://localhost:8080
	@echo "Visit http://localhost:8080 to access Adminer (System: PostgreSQL, Server: db, User: postgres, Password: postgres, Database: reconciliation_api_db)"
