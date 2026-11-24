# Spektrafilm OFX 简体中文代理

给 [spektrafilm OFX](https://spektrafilm.114c.de)（DaVinci Resolve 的胶片模拟插件）提供简体中文界面的**代理 DLL**。

**不改动官方插件的任何字节**，也不包含官方二进制文件。本仓库只提供自己编写的代理层与翻译表。

---

## 原理

OFX 插件在描述参数时会通过宿主（Resolve）的函数表调用 `propSetString`，把
`OfxPropLabel`、`OfxParamPropChoiceOption`、`OfxParamPropHint` 等属性交给宿主显示。

本代理在宿主与插件之间插入一层：

```
Resolve  ──加载──▶  spektrafilm.ofx（本代理）
                        │
                        ├─ 加载同目录 spektrafilm_real.ofx（官方插件）
                        ├─ 包装 OfxHost：只替换 fetchSuite 返回的属性套件
                        └─ propSetString 命中上述属性时，把英文换成中文再转发
```

因此官方插件的渲染、参数逻辑一行都没变，只是它交给宿主的显示文本被替换了。
不需要修改二进制，也就不存在"改坏插件"和"分发被改过的官方二进制"两个问题。

---

## 安装

前置条件：已用官方安装包装好 spektrafilm OFX，并**关闭 DaVinci Resolve**。

1. 下载本仓库的 Release 压缩包，解压到任意目录（路径不要含空格更稳）
2. 双击 `tools\安装中文代理.bat`，UAC 弹窗点「是」
3. 启动 DaVinci Resolve

脚本会把官方插件改名为 `*_real.ofx`，再把代理复制成原名。它是幂等的：
重复运行只会跳过已处理的项目，不会重复改名。

## 还原为英文原版

双击 `tools\还原原版插件.bat`，把 `*_real.ofx` 改回原名并删除代理。

## 插件升级之后

官方安装包会重建整个 bundle 目录，代理会被清掉，插件恢复英文。此时**重新双击
`tools\安装中文代理.bat` 即可**，无需重新编译。新版本如果新增了文案，那些新条目
会显示英文，见下文"补充翻译"。

---

## 自行编译

需要：

- Visual Studio 2022 Build Tools（MSVC x64）
- OpenFX 头文件：把 [ofxa/openfx](https://github.com/ofxa/openfx) 的 `include` 目录
  复制到 `proxy\..\ofx-sdk\include`，或设置环境变量 `OFX_INCLUDE` 指向它

然后运行：

```
proxy\build.bat
```

产物为 `proxy\spektrafilm_zh.ofx`。

## 补充翻译

所有译文集中在 `proxy\zh_table.inc`，格式是 `{"English", "中文"},` 的数组，
按 UTF-8 保存。它由 `docs\汉化对照表.csv` 生成。

修改后重新编译、替换插件目录里的代理文件、重启 Resolve 即可。

---

## 已知限制

- 部分参数的**气泡提示**仍为英文（未收录在翻译表中）
- 插件升级后新增的文案默认显示英文
- 仅支持 Windows x64

---

## 法律声明

- 本项目**不包含** spektrafilm OFX 的任何官方二进制文件或资源文件。
  使用者需自行从[官方网站](https://spektrafilm.114c.de)下载安装。
- 官方插件的代码以 **GPL-3.0** 发布；其二进制包中另含非 GPL 的捆绑资源，
  受 `SPEKTRAFILM_OFX_LICENSE.txt`（Binary Distribution Notice）约束。
  本项目不修改、不重分发这些文件，因此不涉及该声明。
- 本项目的代理代码与翻译表以 **GPL-3.0** 发布，见 `LICENSE`。
- 「spektrafilm」是其作者 Aedan Diez 的商标。本项目为**非官方**汉化项目，
  与作者无隶属或背书关系。

## 致谢

- 插件作者：[Aedan Diez](https://spektrafilm.114c.de)
- 光谱模型参考实现：[Andrea Volpato](https://github.com/andreavolpato/spektrafilm)
