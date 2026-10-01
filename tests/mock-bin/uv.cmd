@echo off
REM mock uv: `tool install openviking` drops a stub server; --version prints version.
echo %* | findstr /c:"tool install openviking" >nul
if %errorlevel%==0 (
  echo @echo off> "%MOCKBIN%\openviking-server.cmd"
  echo echo mock-openviking-server>> "%MOCKBIN%\openviking-server.cmd"
  echo mock uv: installed openviking
  exit /b 0
)
echo uv 0.9.9-mock
exit /b 0
