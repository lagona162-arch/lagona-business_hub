# Supabase Setup Guide

This guide explains how to set up Supabase for the Business Hub application.

## 1. Get Your Supabase Credentials

1. Go to your [Supabase Dashboard](https://app.supabase.com)
2. Select your project (or create a new one)
3. Go to **Settings** → **API**
4. Copy the following:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (the `anon` key)

## 2. Configure the App

Open `lib/config/supabase_config.dart` and update:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
}
```

Replace:
- `https://your-project.supabase.co` with your actual Supabase URL
- `your-anon-key-here` with your actual anon key

## 3. Set Up Database Schema

Follow the schema defined in `DATABASE_SCHEMA.md` to create all necessary tables.

### Quick Setup Steps:

1. Open your Supabase project
2. Go to **SQL Editor**
3. Create the tables by running the SQL statements from `DATABASE_SCHEMA.md`
4. Set up Row Level Security (RLS) policies
5. Create the database functions (optional but recommended)

## 4. Authentication Setup

The app uses Supabase Auth. Make sure:

1. **Email Auth is enabled** in your Supabase project:
   - Go to **Authentication** → **Providers**
   - Ensure "Email" is enabled

2. **Business Hub accounts** should be created with:
   - An auth user (created via Supabase Auth)
   - A corresponding row in the `business_hubs` table

## 5. Row Level Security (RLS)

**Important**: Enable RLS on all tables to ensure data security.

Example RLS policy for `business_hubs`:

```sql
-- Enable RLS
ALTER TABLE business_hubs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own business hub
CREATE POLICY "Business Hub can view own data"
ON business_hubs
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Business Hub can update own data
CREATE POLICY "Business Hub can update own data"
ON business_hubs
FOR UPDATE
USING (auth.uid() = user_id);
```

Apply similar policies to all other tables based on `business_hub_id`.

## 6. Test the Connection

1. Run the app: `flutter run`
2. Try logging in with a test Business Hub account
3. Check the Supabase logs if there are any errors

## 7. Environment Variables (Optional)

For better security, you can use environment variables:

1. Create a `.env` file in the project root:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

2. Use `flutter_dotenv` package to load these values

## Troubleshooting

### Authentication Issues
- Verify the user exists in Supabase Auth
- Check that `business_hubs.user_id` matches `auth.users.id`
- Verify RLS policies allow the user to access their data

### Query Errors
- Check table names match exactly (case-sensitive)
- Verify column names match the schema
- Ensure RLS policies are set correctly

### Connection Errors
- Verify Supabase URL and anon key are correct
- Check internet connection
- Review Supabase project status

## Security Notes

1. **Never commit** your Supabase keys to version control
2. Use RLS policies to restrict data access
3. The anon key is safe to use in client apps (protected by RLS)
4. For sensitive operations, use Supabase Edge Functions with service role key

## Next Steps

- Review `DATABASE_SCHEMA.md` for complete database structure
- Set up database functions for complex operations
- Configure email templates for authentication
- Set up backups and monitoring in Supabase dashboard

