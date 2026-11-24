@echo off
setlocal EnableExtensions

echo ============================================
echo   上传 spektrafilm-zh 到 GitHub
echo ============================================
echo.
echo 请先在 https://github.com/new 建好空仓库：
echo   名称: spektrafilm-zh
echo   类型: Public
echo   不要勾 Add a README file
echo.
set "GHUSER="
set /p GHUSER=请输入你的 GitHub 用户名: 
if "%GHUSER%"=="" (
  echo 用户名不能为空
  pause
  exit /b 1
)

cd /d "%~dp0"

git remote remove origin >nul 2>&1
git remote add origin https://github.com/%GHUSER%/spektrafilm-zh.git

echo.
echo 正在推送，稍后可能弹出浏览器要求登录 GitHub...
echo.
git push -u origin main

if errorlevel 1 (
  echo.
  echo [失败] 推送未成功。常见原因：
  echo   1^) 仓库还没建，或名字不是 spektrafilm-zh
  echo   2^) 登录窗口被关掉了，重新运行本脚本再试
  echo.
) else (
  echo.
  echo [成功] https://github.com/%GHUSER%/spektrafilm-zh
  echo.
  echo 下一步：Releases - Draft a new release
  echo   Tag: v1.0.0
  echo   附件: spektrafilm-zh-1.0.0.zip
)
pause
