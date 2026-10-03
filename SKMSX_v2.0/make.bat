@echo off
rem Build SKMSX.COM (and the skmsx.sym symbol file) with SjASMPlus.
rem   make          build
rem   make clean    remove the generated files
rem Set SJASMPLUS to the assembler if it is not on PATH or in C:\Users\roniv\Dev\bin.
setlocal
cd /d "%~dp0"

if /i "%~1"=="clean" (
    del /q SKMSX.COM skmsx.sym 2>nul
    echo Cleaned.
    exit /b 0
)

if not defined SJASMPLUS (
    if exist "C:\Users\roniv\Dev\bin\sjasmplus.exe" (
        set "SJASMPLUS=C:\Users\roniv\Dev\bin\sjasmplus.exe"
    ) else (
        set "SJASMPLUS=sjasmplus"
    )
)

"%SJASMPLUS%" --nologo --sym=skmsx.sym skmsx.asm
if errorlevel 1 (
    echo.
    echo BUILD FAILED
    exit /b 1
)

for %%F in (SKMSX.COM) do echo Built %%F, %%~zF bytes
exit /b 0
