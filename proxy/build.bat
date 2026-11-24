@echo off
chcp 65001 >nul
setlocal
set "HERE=%~dp0"

rem 需要：Visual Studio 2022 Build Tools（MSVC x64）
rem 需要：OpenFX 头文件放到 ..\ofx-sdk\include\（从 github.com/ofxa/openfx 的 include 目录复制）
rem       也可以用环境变量 OFX_INCLUDE 指定头文件目录

if "%OFX_INCLUDE%"=="" set "OFX_INCLUDE=%HERE%..\ofx-sdk\include"

if not exist "%OFX_INCLUDE%\ofxCore.h" (
  echo [错误] 找不到 OpenFX 头文件：%OFX_INCLUDE%
  echo 请从 https://github.com/ofxa/openfx 的 include 目录复制过来，
  echo 或设置环境变量 OFX_INCLUDE 指向该目录。
  exit /b 1
)

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (
  echo [错误] 未找到 MSVC，请安装 Visual Studio 2022 Build Tools
  exit /b 1
)

if not exist "%HERE%obj" mkdir "%HERE%obj"

cl /nologo /LD /EHsc /utf-8 /std:c++17 /O2 /DNDEBUG ^
   /I "%OFX_INCLUDE%" ^
   "%HERE%spektrafilm_zh.cpp" ^
   /Fe:"%HERE%spektrafilm_zh.ofx" ^
   /Fo:"%HERE%obj\\" ^
   /link /SUBSYSTEM:WINDOWS user32.lib
if errorlevel 1 (
  echo [失败] 编译出错
  exit /b 1
)
echo [完成] 生成 %HERE%spektrafilm_zh.ofx
