@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

:: 还原原版：把 *_real.ofx 改回原名，删掉代理
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
  exit /b 0
)

set "DIR=C:\Program Files\Common Files\OFX\Plugins"

echo === 还原原版插件 ===
for %%n in (spektrafilm spektrafilm_flow spektrafilm_diffuse spektrafilm_lens) do (
  set "BUNDLE=%DIR%\%%n.ofx.bundle\Contents\Win64"
  set "LIVE=!BUNDLE!\%%n.ofx"
  set "REAL=!BUNDLE!\%%n_real.ofx"

  if exist "!REAL!" (
    del /f /q "!LIVE!" >nul 2>&1
    move /y "!REAL!" "!LIVE!" >nul 2>&1
    if exist "!REAL!" (
      echo   %%n : [失败] 文件被占用，请先关闭 DaVinci Resolve
    ) else (
      echo   %%n : 已还原
    )
  ) else (
    echo   %%n : 没有备份，跳过
  )
)
echo.
echo 完成。重启 DaVinci Resolve 生效。
pause
