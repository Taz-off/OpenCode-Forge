@echo off
REM mock npm: `install -g <pkg>` drops a stub; --version prints a version.
echo %* | findstr /c:"install -g @opencode/cli" >nul
if %errorlevel%==0 (
  echo @echo off> "%MOCKBIN%\opencode.cmd"
  echo echo opencode v2.99.9-mock>> "%MOCKBIN%\opencode.cmd"
  echo mock npm: installed @opencode/cli
  exit /b 0
)
echo %* | findstr /c:"install -g tsx" >nul
if %errorlevel%==0 (
  echo @echo off> "%MOCKBIN%\tsx.cmd"
  echo echo 4.99.9-mock>> "%MOCKBIN%\tsx.cmd"
  echo mock npm: installed tsx
  exit /b 0
)
echo 11.99.0-mock
exit /b 0
