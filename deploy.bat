@echo off
set MSG=%~1
if "%MSG%"=="" set MSG=feat: perbarui konten aplikasi

call flutter build web --release
if errorlevel 1 (
  echo Build gagal, deploy dibatalkan.
  exit /b 1
)

findstr /c:"djwcmkngydczvcagmgji" build\web\main.dart.js >nul
if errorlevel 1 (
  echo URL Supabase tidak ada di hasil build, deploy dibatalkan.
  exit /b 1
)

git add .
git add build/web -f
git commit -m "%MSG%"
git push origin main