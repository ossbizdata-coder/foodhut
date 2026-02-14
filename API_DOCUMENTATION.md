# FoodHut Backend API Documentation

**Base URL:** `http://74.208.132.78`

**Authentication:** Bearer Token (obtained from login)

---

## 🔐 Authentication

### POST `/api/auth/login`
**Body:** `{ "email": string, "password": string }`  
**Response:** `{ "token": string, "userId": int, "role": string, "name": string, "email": string }`

### POST `/api/auth/register`
**Body:** `{ "name": string, "email": string, "password": string }`  
**Response:** `200/201` on success

---

## 🍔 Menu Items

### GET `/api/items`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Array of menu items with variations

### POST `/api/items`
**Headers:** `Authorization: Bearer {token}`, `Content-Type: application/json`  
**Body:** 
```json
{
  "name": string,
  "variations": [
    { "variation": string, "price": number, "cost": number }
  ]
}
```

---

## 📊 Sales & Prepared Items

### POST `/api/sales`
**Headers:** `Authorization: Bearer {token}`, `Content-Type: application/json`  
**Body:**
```json
{
  "variationId": int,
  "preparedQty": int,
  "remainingQty": int,
  "actionType": string
}
```

### GET `/api/sales/day?date={YYYY-MM-DD}`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Array of sales for the specified day

### PUT `/api/sales/{saleId}`
**Headers:** `Authorization: Bearer {token}`, `Content-Type: application/json`  
**Description:** Update the quantity of a sale record  
**Body:**
```json
{
  "preparedQty": int,
  "remainingQty": int,
  "actionType": string
}
```
**Response:** `200` on success

### DELETE `/api/sales/{saleId}`
**Headers:** `Authorization: Bearer {token}`  
**Description:** Delete a sale record  
**Response:** `200` or `204` on success

### GET `/api/sales/day/summary?date={YYYY-MM-DD}`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Summary object with totals for the day

---

## 📦 Remaining Items

### GET `/api/remaining/list?date={YYYY-MM-DD}`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Array of remaining items for the specified day

---

## 💰 Expenses

### GET `/api/expenses/types?shopType={FOODHUT}`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Array of expense types

### POST `/api/expenses/types`
**Headers:** `Authorization: Bearer {token}`, `Content-Type: application/json`  
**Body:** `{ "name": string, "shopType": string }`

### POST `/api/transactions`
**Headers:** `Authorization: Bearer {token}`, `Content-Type: application/json`  
**Body:**
```json
{
  "amount": number,
  "category": "EXPENSE",
  "shopType": "FOODHUT",
  "department": "FOODHUT",
  "expenseTypeId": int,
  "comment": string (optional)
}
```

### GET `/api/transactions/daily?department=FOODHUT&category=EXPENSE&date={YYYY-MM-DD}`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Array of expense transactions for the day

### GET `/api/transactions/daily?department=FOODHUT&category=EXPENSE`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Array of all expense transactions (no date filter)

### GET `/api/transactions/daily-summary?department=FOODHUT`
**Headers:** `Authorization: Bearer {token}`  
**Response:** Daily summary with expenses

---

## 📝 Notes

- All authenticated endpoints require `Authorization: Bearer {token}` header
- Date format: `YYYY-MM-DD`
- Department: `FOODHUT`
- Category: `EXPENSE` (for transactions)
- Shop Type: `FOODHUT`

---

## 🐛 Known Issues

- **EntityNotFoundException:** Item ID 27 missing - causing errors when fetching sales data
- Backend may return deleted/orphaned item references
- Client-side date filtering applied for expense queries due to backend inconsistencies

---

**Last Updated:** January 24, 2026

