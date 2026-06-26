# TJS App - Final Setup Steps

## Everything Done ✅
- [x] Flutter app code (30 files) 
- [x] Supabase project created (bkjkcdsvezviuytdwlzg, Mumbai)
- [x] Database schema deployed (3 tables + RLS + triggers)
- [x] Phone Auth enabled with Twilio
- [x] Firebase project created (tjs-app-239f7)
- [x] Android app registered (com.tsjobs.app)
- [x] google-services.json placed
- [x] GitHub repo created (github.com/vinvanku/tjs-app)

## Remaining: Push Code + Add Secrets (2 minutes)

### Step 1: Push code to GitHub
Open terminal in `C:\Users\vinvanku\OneDrive - amazon.com\Personal\R&D_TJS\TJS App\` and run:

```bash
git init
git add .
git commit -m "Initial commit: TJS App - Flutter + Supabase + GitHub Actions"
git branch -M main
git remote add origin https://github.com/vinvanku/tjs-app.git
git push -u origin main
```

### Step 2: Add GitHub Secrets (for the daily scraper)
Go to: https://github.com/vinvanku/tjs-app/settings/secrets/actions

Add these 2 secrets:
| Name | Value |
|------|-------|
| `SUPABASE_URL` | `https://bkjkcdsvezviuytdwlzg.supabase.co` |
| `SUPABASE_KEY` | (copy service_role key from Supabase dashboard → Settings → API Keys → Legacy) |

### Step 3: Get Supabase Anon Key
Go to: https://supabase.com/dashboard/project/bkjkcdsvezviuytdwlzg/settings/api-keys/legacy

Copy the `anon` key (starts with `eyJ...`) and update `lib/utils/constants.dart`:
```dart
static const String supabaseUrl = 'https://bkjkcdsvezviuytdwlzg.supabase.co';
static const String supabaseAnonKey = 'eyJ...YOUR_ANON_KEY...';
```

### Step 4: Run the app
```bash
cd "C:\Users\vinvanku\OneDrive - amazon.com\Personal\R&D_TJS\TJS App"
flutter create .
flutter pub get
flutter run
```

## Credentials Summary
| Service | Key | Value |
|---------|-----|-------|
| Supabase | Project URL | https://bkjkcdsvezviuytdwlzg.supabase.co |
| Supabase | Project Ref | bkjkcdsvezviuytdwlzg |
| Supabase | Region | ap-south-1 (Mumbai) |
| Supabase | DB Password | [REDACTED] |
| Firebase | Project ID | tjs-app-239f7 |
| Firebase | Sender ID | 215445540272 |
| Firebase | App ID | 1:215445540272:android:ceaf9e276a0c9a0a4c9a75 |
| Firebase | Package | com.tsjobs.app |
| Twilio | Account SID | [REDACTED - see Supabase dashboard] |
| Twilio | Phone | +15737283815 |
| GitHub | Repo | github.com/vinvanku/tjs-app |
