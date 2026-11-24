@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: 安装/重装中文代理（幂等，升级官方包之后直接双击本文件即可）
:: 逻辑：真插件(*.ofx 大于 5MB) → 改名为 *_real.ofx；再把代理复制成原名

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
  exit /b 0
)

set "ROOT=%~dp0"
set "PROXY=%ROOT%proxy\spektrafilm_zh.ofx"
set "DIR=C:\Program Files\Common Files\OFX\Plugins"

if not exist "%PROXY%" (
  echo [错误] 找不到代理文件：%PROXY%
  pause
  exit /b 1
)

echo === 安装中文代理 ===
for %%n in (spektrafilm spektrafilm_flow spektrafilm_diffuse spektrafilm_lens) do (
  set "BUNDLE=%DIR%\%%n.ofx.bundle\Contents\Win64"
  set "LIVE=!BUNDLE!\%%n.ofx"
  set "REAL=!BUNDLE!\%%n_real.ofx"

  if not exist "!LIVE!" (
    echo   %%n : 未安装，跳过
  ) else (
    for %%A in ("!LIVE!") do set "SZ=%%~zA"
    if !SZ! LSS 1000000 (
      echo   %%n : 已是代理，跳过
    ) else (
      if exist "!REAL!" del /f /q "!REAL!" >nul 2>&1
      move /y "!LIVE!" "!REAL!" >nul 2>&1
      if exist "!LIVE!" (
        echo   %%n : [失败] 原文件被占用，请先关闭 DaVinci Resolve
      ) else (
        copy /y "%PROXY%" "!LIVE!" >nul 2>&1
        echo   %%n : 已安装代理
      )
    )
  )
)
echo.
echo 完成。重启 DaVinci Resolve 生效。
pause
