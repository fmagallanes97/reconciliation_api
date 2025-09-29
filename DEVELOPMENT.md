
# DB SCHEMA

{
  "transaction_id": "string",
  "account_number": "string",
  "amount_usd": "decimal",
  "created_at": "date"
}


# API SCHEMA

GET /v1/transactions

{
  "account_number": "string",
  "amount": "decimal",
  "currency": "string",
  "created_at": "date",
  "status": "finished"
}




# Filter by amount and date to match the unique transaction

[
{
  "account_number": "string",
  "amount": "decimal",
  "currency": "string",
  "created_at": "date"
},
...
]

->

{
  "transaction_id": "string",
  "account_number": "string",
  "amount_usd": "decimal",
  "created_at": "date"
}

# Filter by amount and date to match the first transaction for the cases we have repeated transactions in the same date

[
{
  "account_number": "string",
  "amount": "decimal",
  "currency": "string",
  "created_at": "date"
},
...
]

->

{
  "transaction_id": "string",
  "account_number": "string",
  "amount_usd": "decimal",
  "created_at": "date"
}


# edge case

- unique transactions (created_at and amount unique)
- repeated transactions in the same date, should be considered as one transaction
