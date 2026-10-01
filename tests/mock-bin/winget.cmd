@echo off
REM mock winget: installs a stub tool instead of downloading.
REM FAIL=1 env -> simulate install failure.
if "%MOCK_WINGET_FAIL%"=="1" (echo mock winget: forced failure>&2 & exit /b 1)
set "ID="
:parse
if "%~1"=="" goto done
if "%~1"=="--id" goto found
shift
goto parse
:found
set "ID=%~2"
shift
shift
goto parse
:done
if "%ID%"=="Git.Git" goto mk_git
if "%ID%"=="OpenJS.NodeJS" goto mk_node
if "%ID%"=="Ollama.Ollama" goto mk_ollama
if "%ID%"=="astral-sh.uv" goto mk_uv
if "%ID%"=="Python.Python.3.12" goto mk_python
echo mock winget: unknown id %ID%>&2
exit /b 1
:mk_git
echo @echo off> "%MOCKBIN%\git.cmd"
echo echo git version 2.99.mock>> "%MOCKBIN%\git.cmd"
goto installed
:mk_node
echo @echo off> "%MOCKBIN%\node.cmd"
echo echo v24.99.0-mock>> "%MOCKBIN%\node.cmd"
goto installed
:mk_ollama
copy "%~dp0ollama.cmd" "%MOCKBIN%\ollama.cmd" >nul
goto installed
:mk_uv
echo @echo off> "%MOCKBIN%\uv.cmd"
echo echo uv 0.9.9-mock>> "%MOCKBIN%\uv.cmd"
goto installed
:mk_python
echo @echo off> "%MOCKBIN%\python.cmd"
echo echo Python 3.12.0-mock>> "%MOCKBIN%\python.cmd"
goto installed
:installed
echo mock winget installed %ID%
exit /b 0
