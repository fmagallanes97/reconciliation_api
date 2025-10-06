defmodule Mix.Tasks.Reconciliation.AuditTransaction do
  use Mix.Task

  @shortdoc "Interactively audit a single internal transaction against the external API"

  @moduledoc """
  Interactive audit logic for transactions.

  **Note:** distributed Mnesia is not implemented.
  If you run this from a CLI or Mix task on a different node than the main app,
  you won't have access to the shared Mnesia data and may see missing data or errors.

  For correct usage, check the README.
  """

  def run(_args) do
    Mix.Task.run("app.start")
    ReconciliationApi.AuditTransaction.run_interactive()
  end
end
