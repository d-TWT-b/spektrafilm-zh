@echo off
setlocal
title spektrafilm-zh 一键上传
set "PS=C:\Program Files\PowerShell\7\pwsh.exe"
if not exist "%PS%" (
  echo 未找到 PowerShell 7，请先安装：https://aka.ms/powershell
  pause
  exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0一键上传.ps1"
if errorlevel 1 pause
