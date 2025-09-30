# Reconciliation API

A robust Elixir application for syncing and reconciling transactions between an external source and an internal database. Includes a CLI audit tool for reporting missing transactions.

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

5. **Stop everything**
   ```sh
   make down
   ```

## Notes

- All sync and mock API parameters are configurable in `config/config.exs`.
- The CLI tool will prompt for page and batch size, and report missing transactions.
