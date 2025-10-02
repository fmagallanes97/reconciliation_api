# Overview

The challenge is to reconcile transactions retrieved from an external API with your internal database records. The goal is to accurately match transactions based on the public API schema, here are the details:


### DB SCHEMA

```json
{
  "transaction_id": "string",
  "account_number": "string",
  "amount_usd": "decimal",
  "created_at": "date"
}
```

**NOTE:** In this challenge, `account_number` represents the origin account (the account from which the transaction originates). The destination account is not included in the provided database schema, as all transactions are assumed to be directed to the same destination account.


### API SCHEMA

```json
{
  "account_number": "string",
  "amount": "decimal",
  "currency": "string",
  "created_at": "date",
  "status": "finished"
}
```

---

## Working Notes

The case of unique transactions is easy to find when we have to reconcile transactions. You can use `account_number`, `amount` and `created_at` to match the unique transaction.
```json
[
  {
    "account_number": "string",                    # variable
    "amount": "string",                            # variable
    "currency": "string",                          # fixed (USD)
    "created_at": "string (ISO8601 date)",         # variable
    "status": "string"                             # fixed (finished)
  }
  ...
]

->

{
  "account_number": "string",
  "amount": "string",
  "currency": "string",
  "created_at": "string (ISO8601 date)",
  "status": "string"
}


```

The problem is that we may have repeated transactions on the same date, with the same amount, and from the same account. To ensure accurate reconciliation, we need to match each transaction 1:1. When fetching transactions from the API, we assume that the order is consistent and follows a FIFO (First-In, First-Out) approach, meaning the earliest transaction is matched first.

```json
  schema "transactions" do
    field(:account_number, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:status, :string)
    field(:created_at, :date)
  end
```

In the proposed schema, we can add an `occurrence_count` field to track how many times a transaction with the same account, amount, and date appears. This column enables us to match transactions in order (using a FIFO approach), ensuring a 1:1 correspondence between records even when there are duplicates.

```json
  schema "transactions" do
    field(:account_number, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:status, :string)
    field(:occurrence_count, :integer)
    field(:created_at, :date)
  end
```
