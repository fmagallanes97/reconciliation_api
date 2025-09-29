def Api do

  @fixed_origin_account_number="0000000001"

  # GET /api/transactions
  def get() do
    {:ok, transactions} = TransactionApi.Api.TransactionController.list_transactions(fixed_origin_account_number)
  end
end
