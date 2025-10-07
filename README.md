# Reconciliation API

Elixir app for syncing and reconciling transactions between an external source and an internal database. Includes a CLI audit tool for reporting missing transactions. See [CHALLENGE.md](./CHALLENGE.md) for the problem description and more context.

## Overview

- **Syncs transactions** from a mock external API into a Postgres database, supporting incremental and full syncs with configurable concurrency and page size.
- **Mock external API** persists transaction data using Mnesia with disk-based storage in Docker volumes.
- **Reconciliation CLI** lets you audit and compare external vs internal transactions.
- **Containerized** with Docker and Docker Compose for easy setup.
- **Makefile** provides shortcuts for common development and ops tasks.

## Requirements

- [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/)
- (Optional for local dev) Elixir ~> 1.18

## How to Run

1. **Build the Docker images**
   ```sh
   make build
   ```

2. **Start the app and database**
   ```sh
   make run
   ```

   **Note:** Database setup and migrations are run automatically when the app container starts (see `entrypoint.sh`). No need to run `make setup`.


3. **View logs**

   ```sh
   make logs
   ```

4. **Open Adminer (Database Browser)**

   ```sh
   make open-adminer
   ```
   This will open Adminer in your default browser at [http://localhost:8080](http://localhost:8080).

   **Note:** Make sure your Docker containers are running (`make run`) so the Adminer service is available.

   **Adminer connection settings:**
   - System: PostgreSQL
   - Server: db
   - Username: postgres
   - Password: postgres
   - Database: reconciliation_api_db

   After running `make open-adminer`, you can log in with the above settings to browse and query your database.

## Extras

- Open an interactive Elixir shell connected to the running app container:

  ```sh
  make iex-connect
  ```

- Remove all containers and volumes (including the database data):

  ```sh
  make clean
  ```

- Stop everything:

  ```sh
  make down
  ```

## Notes

- All sync and mock API parameters are configurable in `config/config.exs`.

## Audit

Interactive audit modules are available for:

- **Audit for missing transactions:** Checks a batch (page) of external transactions and reports which are missing from your internal system.
- **Audit a single transaction:** Search for and reconcile one transaction between the internal and external sources.

To run an audit:

1. Open an interactive Elixir shell connected to the running app container:

   ```sh
   make iex-connect
   ```

2. In the IEx shell, run one of the following commands:

   ```elixir
   ReconciliationApi.AuditMissing.run_interactive()
   ```
   Checks a batch of external transactions and reports which are missing from your internal system.

   ```elixir
   ReconciliationApi.AuditTransaction.run_interactive()
   ```
   Searches for and reconciles a single transaction between the internal and external sources.
