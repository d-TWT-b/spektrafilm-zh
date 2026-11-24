# 一键上传到 GitHub：建仓库 + 推送代码 + 发布 Release（含两个 zip）
# 需要：PowerShell 7、git、一个 GitHub Personal Access Token（scope: repo）
# Token 只在本次运行内使用，不写盘；推送完会把 remote 里的 token 清掉。

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$Root = $PSScriptRoot
$RepoDir = $Root
$SmallZip = Join-Path (Split-Path $Root -Parent) 'spektrafilm-zh-1.0.0.zip'
$FullZip  = Join-Path (Split-Path $Root -Parent) 'spektrafilm-zh-full-1.0.0.zip'

function Line([string]$s = '') { Write-Host $s }
function Ok([string]$s)   { Write-Host "  [OK] $s" -ForegroundColor Green }
function Warn([string]$s) { Write-Host "  [!]  $s" -ForegroundColor Yellow }
function Fail([string]$s) { Write-Host "  [X]  $s" -ForegroundColor Red }

Line '============================================'
Line '   spektrafilm-zh 一键上传到 GitHub'
Line '============================================'
Line

# ---------------- 前置检查 ----------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail ' 未找到 git，请先安装 Git for Windows'
    Read-Host '按回车退出'; exit 1
}
if (-not (Test-Path (Join-Path $RepoDir 'proxy\spektrafilm_zh.cpp'))) {
    Fail " 当前目录不像仓库：$RepoDir"
    Read-Host '按回车退出'; exit 1
}

$owner = Read-Host 'GitHub 用户名'
if ([string]::IsNullOrWhiteSpace($owner)) { Fail '用户名不能为空'; Read-Host; exit 1 }
$owner = $owner.Trim()

$repoName = Read-Host '仓库名（直接回车用 spektrafilm-zh）'
if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = 'spektrafilm-zh' }
$repoName = $repoName.Trim()

Line
Line '需要一个 GitHub Token 才能自动建仓库和发布 Release。'
Line '获取：https://github.com/settings/tokens  →  Generate new token (classic)'
Line '      勾选 repo 权限即可；token 只显示一次，复制下来粘贴到下面。'
Line
$secure = Read-Host '粘贴 Token（输入时不显示）' -AsSecureString
$token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'Token 不能为空'; Read-Host; exit 1 }
$token = $token.Trim()

$headers = @{
    Authorization          = "token $token"
    'User-Agent'           = 'spektrafilm-zh-uploader'
    Accept                 = 'application/vnd.github+json'
}

# ---------------- 校验 token ----------------
Line
Line '正在校验 Token...'
try {
    $me = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -TimeoutSec 30
    Ok ("登录身份：" + $me.login)
    if ($me.login -ne $owner) {
        Warn "你填的用户名是 $owner，但 Token 属于 $($me.login)，将使用 Token 的身份"
        $owner = $me.login
    }
} catch {
    Fail "Token 无效或网络不可达：$($_.Exception.Message)"
    Read-Host '按回车退出'; exit 1
}

# ---------------- 建仓库（已存在则跳过） ----------------
Line
Line '检查仓库...'
$apiRepo = "https://api.github.com/repos/$owner/$repoName"
$exists = $false
try {
    $r = Invoke-RestMethod -Uri $apiRepo -Headers $headers -TimeoutSec 30
    $exists = $true
    Ok ("仓库已存在：" + $r.full_name)
} catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 404) {
        Warn ("查询仓库失败：" + $_.Exception.Message)
    }
}

if (-not $exists) {
    Line '  创建仓库...'
    $body = @{
        name        = $repoName
        description = 'spektrafilm OFX 简体中文代理（非官方汉化）'
        private     = $false
        has_issues  = $true
        has_wiki    = $false
    } | ConvertTo-Json
    try {
        $r = Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Method Post `
             -Headers $headers -Body $body -ContentType 'application/json' -TimeoutSec 60
        Ok ("已创建：" + $r.html_url)
    } catch {
        Fail ("创建仓库失败：" + $_.Exception.Message)
        Read-Host '按回车退出'; exit 1
    }
}

# ---------------- 推送代码 ----------------
Line
Line '推送代码...'
Push-Location $RepoDir
try {
    if (-not (Test-Path '.git')) { git init -b main | Out-Null }

    # 提交（有改动才提交）
    git add . | Out-Null
    $status = git status --porcelain
    if ($status) {
        git -c user.name='spektrafilm-zh' -c user.email='noreply@example.com' `
            commit -m 'chore: 上传前同步' | Out-Null
        Ok '已提交本地改动'
    } else {
        Ok '没有未提交的改动'
    }

    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if (-not $branch) { $branch = 'main' }

    # 带 token 推送（避免弹登录框），推送后清除
    git remote remove origin 2>$null | Out-Null
    git remote add origin "https://x-access-token:$token@github.com/$owner/$repoName.git"

    # 证书后端：优先 schannel（用 Windows 证书存储），失败再退回关闭校验
    $sslArgs = @('-c', 'http.sslBackend=schannel')
    Line '  推送中（使用 Windows 证书存储）...'
    git @sslArgs push -u origin $branch 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
    $pushOk = ($LASTEXITCODE -eq 0)

    if (-not $pushOk) {
        Warn 'schannel 推送失败，尝试关闭 SSL 校验（仅本次，不写配置）'
        git -c http.sslVerify=false push -u origin $branch 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
        $pushOk = ($LASTEXITCODE -eq 0)
        if ($pushOk) { Warn '已用跳过证书校验的方式推送成功（网络环境证书链不完整，属常见情况）' }
    }

    if (-not $pushOk) { throw "git push 失败，退出码 $LASTEXITCODE" }
    Ok "代码已推送（$branch）"

    git remote set-url origin "https://github.com/$owner/$repoName.git"
    Ok 'remote 已还原为不含 token 的地址'
}
finally { Pop-Location }

# ---------------- 创建 Release 并上传附件 ----------------
Line
Line '创建 Release 并上传附件...'

$tag = 'v1.0.0'
$releaseExists = $false
try {
    $rel = Invoke-RestMethod -Uri "$apiRepo/releases/tags/$tag" -Headers $headers -TimeoutSec 30
    $releaseExists = $true
    Ok "Release $tag 已存在，将上传新附件"
} catch { }

if (-not $releaseExists) {
    $body = @{
        tag_name   = $tag
        name       = 'v1.0.0 首个中文版'
        body       = @"
## 内容

- ``spektrafilm-zh-full-1.0.0.zip`` —— 整合包：官方原包（未修改）+ 中文代理 + 一键安装
- ``spektrafilm-zh-1.0.0.zip`` —— 小包：仅中文代理，适合已安装官方插件者

## 安装

解压后双击 ``一键安装中文版.bat``，UAC 点「是」，重启 DaVinci Resolve。

官方插件文件不做任何修改；官方压缩包原样保留，受其 Binary Distribution Notice 约束。
本项目为非官方汉化，与作者无隶属关系。
"@
        draft      = $false
        prerelease = $false
    } | ConvertTo-Json -Depth 5
    try {
        $rel = Invoke-RestMethod -Uri "$apiRepo/releases" -Method Post -Headers $headers `
               -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 60
        Ok ("Release 已创建：" + $rel.html_url)
    } catch {
        Fail ("创建 Release 失败：" + $_.Exception.Message)
        Read-Host '按回车退出'; exit 1
    }
}

$uploadUrl = ($rel.upload_url -replace '\{.*\}$', '')
foreach ($zip in @($FullZip, $SmallZip)) {
    if (-not (Test-Path $zip)) { Warn " 找不到附件：$zip"; continue }
    $name = Split-Path $zip -Leaf
    $mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
    Line "  上传 $name（$mb MB）..."
    try {
        $bytes = [IO.File]::ReadAllBytes($zip)
        $res = Invoke-RestMethod -Uri "$uploadUrl?name=$([uri]::EscapeDataString($name))" -Method Post `
               -Headers $headers -Body $bytes -ContentType 'application/octet-stream' -TimeoutSec 900
        Ok ("已上传：" + $res.name)
    } catch {
        Warn ("上传失败：" + $_.Exception.Message)
        Warn '可以稍后在网页上手动拖入附件'
    }
}

Line
Line '============================================'
Ok ' 全部完成'
Line " 仓库：https://github.com/$owner/$repoName"
Line " 发布：https://github.com/$owner/$repoName/releases"
Line '============================================'
Line
Read-Host '按回车退出'
