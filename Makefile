.PHONY: setup build run down logs shell migrate reset reconciliation_audit open-adminer iex-connect

include .env

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

clean:
	docker compose down -v

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
	@open "http://localhost:8080/?pgsql=db&username=postgres&db=reconciliation_api_db" || \
	xdg-open "http://localhost:8080/?pgsql=db&username=postgres&db=reconciliation_api_db" || \
	start "http://localhost:8080/?pgsql=db&username=postgres&db=reconciliation_api_db"
	@echo "Visit http://localhost:8080 to access Adminer (System: PostgreSQL, Server: db, User: postgres, Password: postgres, Database: reconciliation_api_db)"

iex-connect:
	docker compose exec app iex --sname shell --remsh $(ERL_NODE_NAME) --cookie $(ERL_COOKIE)
