@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem 一键安装：官方原包（official 目录里的 zip）+ 中文代理
rem 官方包保持原样解压安装，不做任何修改；之后再安装代理层。

title spektrafilm 中文版 一键安装

echo ============================================
echo   spektrafilm OFX 中文版 一键安装
echo ============================================
echo.

rem ---- 提权 ----
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo 需要管理员权限，正在请求...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
  exit /b 0
)

set "HERE=%~dp0"
set "ZIP="
for %%z in ("%HERE%official\*.zip") do set "ZIP=%%~fz"

if "%ZIP%"=="" (
  echo [错误] 找不到官方安装包。
  echo 请把 spektrafilm-OFX-Windows.zip 放到 official 目录下再运行。
  pause
  exit /b 1
)

echo 官方包：%ZIP%
echo.

rem ---- 解压官方包到临时目录 ----
set "TMP=%TEMP%\spektrafilm_official"
if exist "%TMP%" rmdir /s /q "%TMP%" >nul 2>&1
echo [1/3] 解压官方包...
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%TMP%' -Force"
if not exist "%TMP%\install.bat" (
  echo [错误] 官方包里没有 install.bat，包可能不完整。
  pause
  exit /b 1
)

rem ---- 调用官方安装 ----
echo [2/3] 安装官方插件（会覆盖旧版本）...
pushd "%TMP%"
call install.bat --elevated-copy
set "RC=!errorlevel!"
popd

if not "!RC!"=="0" (
  echo [错误] 官方安装失败，退出码 !RC!
  pause
  exit /b 1
)
rmdir /s /q "%TMP%" >nul 2>&1

rem ---- 安装中文代理 ----
echo [3/3] 安装中文代理...
set "PROXY=%HERE%proxy\spektrafilm_zh.ofx"
set "DIR=C:\Program Files\Common Files\OFX\Plugins"

if not exist "%PROXY%" (
  echo [错误] 找不到代理文件 proxy\spektrafilm_zh.ofx
  pause
  exit /b 1
)

for %%n in (spektrafilm spektrafilm_flow spektrafilm_diffuse spektrafilm_lens) do (
  set "B=LIVE"
  set "BUNDLE=%DIR%\%%n.ofx.bundle\Contents\Win64"
  set "LIVE=!BUNDLE!\%%n.ofx"
  set "REAL=!BUNDLE!\%%n_real.ofx"
  if exist "!LIVE!" (
    for %%A in ("!LIVE!") do set "SZ=%%~zA"
    if !SZ! LSS 1000000 (
      echo    %%n : 已是代理
    ) else (
      if exist "!REAL!" del /f /q "!REAL!" >nul 2>&1
      move /y "!LIVE!" "!REAL!" >nul 2>&1
      copy /y "%PROXY%" "!LIVE!" >nul 2>&1
      echo    %%n : 完成
    )
  ) else (
    echo    %%n : 未找到，跳过
  )
)

echo.
echo ============================================
echo   完成，请重启 DaVinci Resolve
echo ============================================
echo.
echo 还原英文原版：双击 还原原版插件.bat
echo.
pause
