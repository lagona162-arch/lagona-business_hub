# Database Schema Documentation

This document outlines the expected Supabase database schema for the Business Hub application.

## Required Tables

### 1. `business_hubs`
Business Hub accounts (created by admin panel).

```sql
CREATE TABLE business_hubs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) UNIQUE NOT NULL,
  name TEXT NOT NULL,
  bh_code TEXT UNIQUE NOT NULL,
  balance DECIMAL(12,2) DEFAULT 0.00,
  bonus_credits DECIMAL(12,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_business_hubs_user_id ON business_hubs(user_id);
CREATE INDEX idx_business_hubs_bh_code ON business_hubs(bh_code);
```

### 2. `loading_stations`
Loading Stations managed by Business Hubs.

```sql
CREATE TABLE loading_stations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_hub_id UUID REFERENCES business_hubs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  ls_code TEXT UNIQUE NOT NULL,
  balance DECIMAL(12,2) DEFAULT 0.00,
  status TEXT DEFAULT 'active', -- 'active', 'inactive', 'blacklisted'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_loading_stations_bh_id ON loading_stations(business_hub_id);
CREATE INDEX idx_loading_stations_ls_code ON loading_stations(ls_code);
```

### 3. `topup_requests`
Top-up requests from Loading Stations to Business Hubs.

```sql
CREATE TABLE topup_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loading_station_id UUID REFERENCES loading_stations(id) ON DELETE CASCADE,
  business_hub_id UUID REFERENCES business_hubs(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  rejection_reason TEXT,
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_topup_requests_bh_id ON topup_requests(business_hub_id);
CREATE INDEX idx_topup_requests_ls_id ON topup_requests(loading_station_id);
CREATE INDEX idx_topup_requests_status ON topup_requests(status);
```

### 4. `bh_topup_requests`
Top-up requests from Business Hubs to Admin.

```sql
CREATE TABLE bh_topup_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_hub_id UUID REFERENCES business_hubs(id) ON DELETE CASCADE,
  requested_amount DECIMAL(12,2) NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  rejection_reason TEXT,
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  approved_by UUID REFERENCES auth.users(id), -- Admin user ID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bh_topup_requests_bh_id ON bh_topup_requests(business_hub_id);
CREATE INDEX idx_bh_topup_requests_status ON bh_topup_requests(status);
```

### 5. `transactions`
Transaction history for all entities.

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_hub_id UUID REFERENCES business_hubs(id),
  type TEXT NOT NULL, -- 'topup', 'commission', 'bonus'
  amount DECIMAL(12,2) NOT NULL,
  bonus_amount DECIMAL(12,2) DEFAULT 0.00,
  from_entity_id UUID, -- Loading Station or Rider ID
  from_entity_type TEXT, -- 'loading_station', 'rider'
  status TEXT DEFAULT 'pending', -- 'pending', 'completed', 'failed'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transactions_bh_id ON transactions(business_hub_id);
CREATE INDEX idx_transactions_type ON transactions(type);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
```

### 6. `commissions`
Commission records for Business Hubs.

```sql
CREATE TABLE commissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_hub_id UUID REFERENCES business_hubs(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id),
  commission_rate DECIMAL(5,4) NOT NULL, -- e.g., 0.0500 for 5%
  commission_amount DECIMAL(12,2) NOT NULL,
  bonus_amount DECIMAL(12,2) DEFAULT 0.00,
  source_type TEXT NOT NULL, -- 'topup', 'rider_transaction'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_commissions_bh_id ON commissions(business_hub_id);
CREATE INDEX idx_commissions_transaction_id ON commissions(transaction_id);
CREATE INDEX idx_commissions_created_at ON commissions(created_at);
```

### 7. `blacklisted_accounts`
Blacklisted accounts (Loading Stations or Riders).

```sql
CREATE TABLE blacklisted_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_hub_id UUID REFERENCES business_hubs(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL, -- 'loading_station', 'rider'
  entity_id UUID NOT NULL, -- Loading Station or Rider ID
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'blacklisted', -- 'blacklisted', 'pending_reapplication', 'approved'
  blacklisted_at TIMESTAMPTZ DEFAULT NOW(),
  reapplication_requested_at TIMESTAMPTZ,
  reapplication_approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_blacklisted_bh_id ON blacklisted_accounts(business_hub_id);
CREATE INDEX idx_blacklisted_entity ON blacklisted_accounts(entity_type, entity_id);
CREATE INDEX idx_blacklisted_status ON blacklisted_accounts(status);
```

## Database Functions (Optional but Recommended)

### Generate BHCODE Function
```sql
CREATE OR REPLACE FUNCTION generate_bhcode(bh_id UUID)
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  max_num INTEGER;
BEGIN
  -- Get the highest number from existing BH codes
  SELECT COALESCE(MAX(CAST(SUBSTRING(bh_code FROM 3) AS INTEGER)), 0)
  INTO max_num
  FROM business_hubs
  WHERE bh_code ~ '^BH[0-9]+$';
  
  -- Generate new code
  new_code := 'BH' || LPAD((max_num + 1)::TEXT, 3, '0');
  
  -- Update the business hub
  UPDATE business_hubs
  SET bh_code = new_code, updated_at = NOW()
  WHERE id = bh_id;
  
  RETURN new_code;
END;
$$ LANGUAGE plpgsql;
```

### Approve Top-Up Request Function
This function should handle the transaction atomically (deduct from BH, add to LS).

```sql
CREATE OR REPLACE FUNCTION approve_topup_request(
  request_id UUID,
  bh_id UUID
)
RETURNS VOID AS $$
DECLARE
  req_record RECORD;
BEGIN
  -- Get request details
  SELECT * INTO req_record
  FROM topup_requests
  WHERE id = request_id
    AND business_hub_id = bh_id
    AND status = 'pending';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Top-up request not found or already processed';
  END IF;
  
  -- Check if Business Hub has sufficient balance
  IF (SELECT balance FROM business_hubs WHERE id = bh_id) < req_record.amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;
  
  -- Deduct from Business Hub balance
  UPDATE business_hubs
  SET balance = balance - req_record.amount,
      updated_at = NOW()
  WHERE id = bh_id;
  
  -- Add to Loading Station wallet
  UPDATE loading_stations
  SET balance = balance + req_record.amount,
      updated_at = NOW()
  WHERE id = req_record.loading_station_id;
  
  -- Update request status
  UPDATE topup_requests
  SET status = 'approved',
      approved_at = NOW(),
      updated_at = NOW()
  WHERE id = request_id;
  
  -- Create transaction record
  INSERT INTO transactions (
    business_hub_id,
    type,
    amount,
    from_entity_id,
    from_entity_type,
    status,
    created_at
  ) VALUES (
    bh_id,
    'topup',
    req_record.amount,
    req_record.loading_station_id,
    'loading_station',
    'completed',
    NOW()
  );
END;
$$ LANGUAGE plpgsql;
```

## Row Level Security (RLS) Policies

Enable RLS on all tables and create policies to ensure Business Hubs can only access their own data:

```sql
-- Enable RLS
ALTER TABLE business_hubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE loading_stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE topup_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE bh_topup_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE blacklisted_accounts ENABLE ROW LEVEL SECURITY;

-- Example policy for business_hubs
CREATE POLICY "Business Hub can view own data"
ON business_hubs
FOR SELECT
USING (auth.uid() = user_id);

-- Example policy for loading_stations
CREATE POLICY "Business Hub can view own loading stations"
ON loading_stations
FOR SELECT
USING (
  business_hub_id IN (
    SELECT id FROM business_hubs WHERE user_id = auth.uid()
  )
);
```

## Notes

1. **Timestamps**: All tables use `TIMESTAMPTZ` for timezone-aware timestamps
2. **IDs**: Use UUIDs for all primary keys
3. **Decimals**: Use `DECIMAL(12,2)` for currency amounts to ensure precision
4. **Foreign Keys**: Proper foreign key constraints ensure data integrity
5. **Indexes**: Add indexes on frequently queried columns for performance
6. **RLS**: Row Level Security ensures users can only access their own data

## Environment Variables

Make sure to set these in your Supabase project:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous/public key

These should be configured in `lib/config/supabase_config.dart`.

