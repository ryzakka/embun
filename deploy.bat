@echo off
set MSG=%~1
if "%MSG%"=="" set MSG=feat: perbarui konten aplikasi

call flutter build web --release --dart-define=SUPABASE_URL=https://djwcmkngydczvcagmgji.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqd2Nta25neWRjenZjYWdtZ2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5NTYwODAsImV4cCI6MjEwODUzMjA4MH0.-_pVJJVdrwgInDMxA3braNna0G2eVHtmkGXnw6--Mr8
if errorlevel 1 (
  echo Build gagal, deploy dibatalkan.
  exit /b 1
)

git add .
git add build/web -f
git commit -m "%MSG%"
git push origin main