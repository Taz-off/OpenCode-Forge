@echo off
REM mock ollama. Models state in %MOCK_MODELS% file. Commands: --version, list, pull <m>, run <m> <prompt>, serve
if "%~1"=="--version" (echo ollama version is 0.99.0-mock & exit /b 0)
if "%~1"=="list" (
  echo NAME                    ID              SIZE      MODIFIED
  if exist "%MOCK_MODELS%" (type "%MOCK_MODELS%")
  exit /b 0
)
if "%~1"=="pull" (
  echo %~2                     abc123          1.0 GB      mock>> "%MOCK_MODELS%"
  echo mock ollama: pulled %~2
  exit /b 0
)
if "%~1"=="run" (
  echo OK
  exit /b 0
)
if "%~1"=="serve" (echo mock ollama serve & exit /b 0)
echo mock ollama: unknown args %*
exit /b 0
