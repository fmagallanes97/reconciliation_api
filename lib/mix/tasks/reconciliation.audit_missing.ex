defmodule Mix.Tasks.Reconciliation.AuditMissing do
  use Mix.Task

  @shortdoc "Batch audit: reports transactions missing in the internal DB compared to the external API"

  @moduledoc """
  Batch audit for missing transactions.

  **Note:** Distributed Mnesia is not implemented.
  If you run this from a CLI or Mix task on a different node than the main app,
  you won't have access to the shared Mnesia data and may see missing data or errors.

  For correct usage, check the README.
  """

  def run(_args) do
    Mix.Task.run("app.start")
    ReconciliationApi.AuditMissing.run_interactive()
  end
end
