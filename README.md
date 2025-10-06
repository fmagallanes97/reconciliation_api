# Reconciliation API

Elixir app for syncing and reconciling transactions between an external source and an internal database. Includes a CLI audit tool for reporting missing transactions. See [CHALLENGE.md](./CHALLENGE.md) for the problem description and more context.

## Overview

- **Syncs transactions** from a mock external API into a Postgres database.
- **Supports incremental and full syncs** with configurable concurrency and page size.
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

3. **Run the reconciliation audit CLI**
   ```sh
   make reconciliation_audit
   ```

4. **View logs**
   ```sh
   make logs
   ```

5. **Open Adminer (Database Browser)**
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

## Notes

- All sync and mock API parameters are configurable in `config/config.exs`.
- The CLI tool will prompt for page and batch size, and report missing transactions.

## Extras

Open an interactive Elixir shell connected to the running app container using:

```sh
make iex-connect
```

Remove all containers and volumes (including the database data) with:

```sh
make clean
```

Stop everything

```sh
make down
```

## CLI Toolkit

The project provides CLI tools for reconciliation and auditing. These are implemented as custom Mix tasks and can be run using Makefile shortcuts from your project root (inside the container).

### Commands

**Batch audit**:
Reports external transactions missing in the internal database, including duplicate occurrences. Prompts for page number and page size to fetch from the external API.
```sh
make audit_missing
```

**Audit Transaction**:
Interactively search for and reconcile a specific internal transaction with the external API. Prompts for search criteria, lets you pick a transaction, and attempts reconciliation.
```sh
make audit_transaction
```
