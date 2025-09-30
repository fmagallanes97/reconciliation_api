#!/bin/sh

mix deps.get
mix ecto.create
mix ecto.migrate

exec "_build/prod/rel/reconciliation_api/bin/reconciliation_api" start
