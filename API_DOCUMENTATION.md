# Business Hub API Documentation

This document outlines all the API endpoints required for the Business Hub Flutter application.

## Base URL Configuration

Update the base URL in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'https://your-api-domain.com/api'; // Replace with actual API URL
```

## Authentication

All API requests (except login) require a Bearer token in the Authorization header:
```
Authorization: Bearer <token>
```

---

## API Endpoints

### 1. Authentication

#### Login
- **Method:** `POST`
- **Endpoint:** `/auth/login`
- **Request Body:**
```json
{
  "username": "business_hub_username",
  "password": "password123"
}
```
- **Success Response (200):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "bh_123",
    "name": "Business Hub Name",
    "bh_code": "BH001",
    "balance": 50000.00,
    "bonus_credits": 7500.00,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```
- **Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

### 2. Hierarchy Management

#### Generate BHCODE
- **Method:** `POST`
- **Endpoint:** `/business-hub/generate-bhcode`
- **Request Body:** `{}`
- **Success Response (200):**
```json
{
  "bh_code": "BH002",
  "message": "BHCODE generated successfully"
}
```

#### Get Loading Stations
- **Method:** `GET`
- **Endpoint:** `/business-hub/loading-stations`
- **Success Response (200):**
```json
{
  "data": [
    {
      "id": "ls_123",
      "name": "Loading Station 1",
      "bh_code": "BH001",
      "ls_code": "LS001",
      "balance": 10000.00,
      "status": "active",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

---

### 3. Top-Up Requests (Loading Station → Business Hub)

#### Get Top-Up Requests
- **Method:** `GET`
- **Endpoint:** `/business-hub/topup-requests?status=pending` (optional query param: `status`)
- **Success Response (200):**
```json
{
  "data": [
    {
      "id": "req_123",
      "loading_station_id": "ls_123",
      "loading_station_name": "Loading Station 1",
      "loading_station_code": "LS001",
      "amount": 5000.00,
      "status": "pending",
      "rejection_reason": null,
      "requested_at": "2024-01-15T10:00:00Z",
      "approved_at": null,
      "rejected_at": null
    }
  ]
}
```

#### Approve Top-Up Request
- **Method:** `POST`
- **Endpoint:** `/business-hub/topup-requests/{requestId}/approve`
- **Request Body:** `{}`
- **Success Response (200):**
```json
{
  "success": true,
  "message": "Top-up request approved",
  "transaction": {
    "id": "trans_123",
    "type": "topup",
    "amount": 5000.00,
    "bonus_amount": 0,
    "from_entity_id": "ls_123",
    "from_entity_type": "loading_station",
    "from_entity_name": "Loading Station 1",
    "status": "completed",
    "created_at": "2024-01-15T10:05:00Z"
  }
}
```
- **Note:** This should:
  - Deduct `amount` from Business Hub balance
  - Add `amount` to Loading Station wallet
  - Create a transaction record

#### Reject Top-Up Request
- **Method:** `POST`
- **Endpoint:** `/business-hub/topup-requests/{requestId}/reject`
- **Request Body:**
```json
{
  "reason": "Insufficient funds"
}
```
- **Success Response (200):**
```json
{
  "success": true,
  "message": "Top-up request rejected"
}
```

---

### 4. Business Hub Top-Up Requests (Business Hub → Admin)

#### Request Top-Up from Admin
- **Method:** `POST`
- **Endpoint:** `/business-hub/request-topup`
- **Request Body:**
```json
{
  "amount": 50000.00
}
```
- **Success Response (200):**
```json
{
  "success": true,
  "request": {
    "id": "bh_req_123",
    "requested_amount": 50000.00,
    "status": "pending",
    "rejection_reason": null,
    "requested_at": "2024-01-15T10:00:00Z",
    "approved_at": null,
    "rejected_at": null,
    "approved_by": null
  }
}
```

#### Get Business Hub Top-Up Requests
- **Method:** `GET`
- **Endpoint:** `/business-hub/my-topup-requests?status=pending` (optional query param: `status`)
- **Success Response (200):**
```json
{
  "data": [
    {
      "id": "bh_req_123",
      "requested_amount": 50000.00,
      "status": "approved",
      "rejection_reason": null,
      "requested_at": "2024-01-15T10:00:00Z",
      "approved_at": "2024-01-15T11:00:00Z",
      "rejected_at": null,
      "approved_by": "admin_user"
    }
  ]
}
```

---

### 5. Commissions

#### Get Commissions
- **Method:** `GET`
- **Endpoint:** `/business-hub/commissions?start_date=2024-01-01T00:00:00Z&end_date=2024-01-31T23:59:59Z` (optional query params)
- **Success Response (200):**
```json
{
  "data": [
    {
      "id": "comm_123",
      "transaction_id": "trans_123",
      "commission_rate": 0.05,
      "commission_amount": 250.00,
      "bonus_amount": 50.00,
      "source_type": "topup",
      "created_at": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

### 6. Monitoring & Oversight

#### Get Top-Up Transactions
- **Method:** `GET`
- **Endpoint:** `/business-hub/transactions/topup?start_date=2024-01-01T00:00:00Z&end_date=2024-01-31T23:59:59Z&loading_station_id=ls_123` (optional query params)
- **Success Response (200):**
```json
{
  "data": [
    {
      "id": "trans_123",
      "type": "topup",
      "amount": 5000.00,
      "bonus_amount": 0,
      "from_entity_id": "ls_123",
      "from_entity_type": "loading_station",
      "from_entity_name": "Loading Station 1",
      "status": "completed",
      "created_at": "2024-01-15T10:00:00Z"
    }
  ]
}
```

#### Get Balance and Cash Flow
- **Method:** `GET`
- **Endpoint:** `/business-hub/balance-cashflow`
- **Success Response (200):**
```json
{
  "total_loading_balance": 100000.00,
  "monthly_cashflow": 50000.00,
  "total_transactions": 150,
  "current_balance": 75000.00,
  "bonus_credits": 11250.00
}
```

---

### 7. Admin Control

#### Get Blacklisted Accounts
- **Method:** `GET`
- **Endpoint:** `/business-hub/blacklisted-accounts`
- **Success Response (200):**
```json
{
  "data": [
    {
      "id": "blacklist_123",
      "entity_type": "loading_station",
      "entity_id": "ls_123",
      "entity_name": "Loading Station 1",
      "reason": "Violation of terms",
      "status": "pending_reapplication",
      "blacklisted_at": "2024-01-01T00:00:00Z",
      "reapplication_requested_at": "2024-01-10T00:00:00Z",
      "reapplication_approved_at": null
    }
  ]
}
```

#### Approve Reapplication
- **Method:** `POST`
- **Endpoint:** `/business-hub/blacklisted-accounts/{blacklistedAccountId}/approve`
- **Request Body:** `{}`
- **Success Response (200):**
```json
{
  "success": true,
  "message": "Reapplication approved"
}
```

---

## Error Handling

All error responses should follow this format:

```json
{
  "success": false,
  "message": "Error description",
  "error_code": "ERROR_CODE" // optional
}
```

**Common HTTP Status Codes:**
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `500` - Internal Server Error

---

## Data Types

- **Dates:** ISO 8601 format (e.g., `2024-01-15T10:00:00Z`)
- **Currency:** Decimal numbers (e.g., `5000.00`)
- **IDs:** String format (e.g., `bh_123`, `ls_456`)
- **Status Values:**
  - Top-up requests: `pending`, `approved`, `rejected`
  - Blacklist status: `blacklisted`, `pending_reapplication`, `approved`
  - Transaction status: `pending`, `completed`, `failed`

---

## Notes for Backend Implementation

1. **Balance Updates:**
   - When approving a top-up request from Loading Station:
     - Deduct from Business Hub balance
     - Add to Loading Station wallet
   - When Admin approves Business Hub top-up request:
     - Add to Business Hub balance (amount is hardcoded/set by admin)

2. **Authentication:**
   - Validate JWT token on all protected endpoints
   - Return 401 if token is invalid or expired

3. **Permissions:**
   - Ensure Business Hub can only access their own data
   - Filter Loading Stations by Business Hub's BHCODE

4. **Transaction Tracking:**
   - Create transaction records for all balance changes
   - Include timestamps and status updates

---

## Example API Base URL Configuration

For development:
```dart
static const String baseUrl = 'http://localhost:3000/api';
```

For production:
```dart
static const String baseUrl = 'https://api.yourdomain.com/api';
```

For staging:
```dart
static const String baseUrl = 'https://staging-api.yourdomain.com/api';
```

