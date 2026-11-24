// Spektrafilm OFX 简体中文代理
//
// 原理：宿主（DaVinci Resolve）加载本 DLL 后，本 DLL 再加载官方插件
//      （同目录下的 *_real.ofx）。我们给官方插件一个"包装过的宿主"：
//      只替换 fetchSuite 返回的属性套件中的 propSetString，
//      把 OfxPropLabel / ShortLabel / LongLabel / ChoiceOption / Hint
//      的英文换成中文，再原样转发给真正的宿主。
//
//      官方插件一个字节都不修改，渲染与参数逻辑完全不受影响。
//
// 构建：见 proxy/build.bat（需要 MSVC + OpenFX 头文件）

#include <windows.h>
#include <string>
#include <unordered_map>

#include "ofxCore.h"
#include "ofxProperty.h"
#include "ofxParam.h"
#include "ofxImageEffect.h"

// ---------------------------------------------------------------- 翻译表
struct Translation { const char* en; const char* zh; };

static const Translation kTable[] = {
#include "zh_table.inc"
};

// 插件自身名称 / 分组名（优先匹配，不受原字符串长度限制）
static const Translation kPluginNames[] = {
    {"Spektrafilm OFX",     "Spektrafilm 胶片模拟"},
    {"spektrafilm",         "Spektrafilm 胶片模拟"},
    {"Spektrafilm",         "Spektrafilm 胶片模拟"},
    {"Spektrafilm diffuse", "Spektrafilm 扩散"},
    {"Spektrafilm flow",    "Spektrafilm 快速版"},
    {"Spektrafilm lens",    "Spektrafilm 镜头"},
    {"spektrafilm_flow",    "Spektrafilm 快速版"},
    {"spektrafilm_diffuse", "Spektrafilm 扩散"},
    {"spektrafilm_lens",    "Spektrafilm 镜头"},
};

static const std::unordered_map<std::string, std::string>& Table()
{
    static std::unordered_map<std::string, std::string> map = [] {
        std::unordered_map<std::string, std::string> m;
        m.reserve((sizeof(kTable) / sizeof(kTable[0])) * 2);
        for (const auto& t : kTable) m.emplace(t.en, t.zh);
        return m;
    }();
    return map;
}

static const char* Translate(const char* s)
{
    if (!s || !*s) return s;
    for (const auto& t : kPluginNames)
        if (std::string(s) == t.en) return t.zh;
    const auto& m = Table();
    auto it = m.find(std::string(s));
    return (it == m.end()) ? s : it->second.c_str();
}

static bool ShouldTranslate(const char* property)
{
    if (!property) return false;
    const std::string k(property);
    return k == kOfxPropLabel ||
           k == kOfxPropShortLabel ||
           k == kOfxPropLongLabel ||
           k == kOfxParamPropChoiceOption ||
           k == kOfxParamPropHint ||
           k == kOfxImageEffectPluginPropGrouping;
}

// ---------------------------------------------------------------- 全局状态
static HMODULE            g_self         = nullptr;
static HMODULE            g_real         = nullptr;
static const OfxHost*     g_realHost     = nullptr;
static OfxHost            g_wrappedHost{};
static OfxPropertySuiteV1 g_propSuite{};
static bool               g_propPatched  = false;
static OfxStatus (*g_realPropSetString)(OfxPropertySetHandle, const char*, int, const char*) = nullptr;

using OfxGetNumFn    = int (*)();
using OfxGetPluginFn = OfxPlugin* (*)(int);

static OfxGetNumFn    g_realGetNum    = nullptr;
static OfxGetPluginFn g_realGetPlugin = nullptr;

static const int kMaxPlugins = 8;

struct Wrapper {
    OfxPlugin pub{};
    void (*realSetHost)(OfxHost*) = nullptr;
    bool used = false;
};

static Wrapper g_wrappers[kMaxPlugins];

// ---------------------------------------------------------------- 属性套件代理
static OfxStatus wrappedPropSetString(OfxPropertySetHandle properties,
                                      const char* property,
                                      int index,
                                      const char* value)
{
    const char* out = ShouldTranslate(property) ? Translate(value) : value;
    return g_realPropSetString(properties, property, index, out);
}

// ---------------------------------------------------------------- 宿主套件代理
static const void* wrappedFetchSuite(OfxPropertySetHandle host, const char* suiteName, int suiteVersion)
{
    if (!g_realHost || !g_realHost->fetchSuite) return nullptr;

    const void* suite = g_realHost->fetchSuite(host, suiteName, suiteVersion);
    if (!suite) return nullptr;

    if (suiteName && std::string(suiteName) == kOfxPropertySuite && suiteVersion == 1) {
        if (!g_propPatched) {
            g_propSuite = *static_cast<const OfxPropertySuiteV1*>(suite);
            g_realPropSetString = g_propSuite.propSetString;
            g_propSuite.propSetString = &wrappedPropSetString;
            g_propPatched = true;
        }
        return &g_propSuite;
    }
    return suite;
}

// 每个插件一个 setHost 入口，避免共享全局状态导致串号
static void SetHostImpl(int slot, const OfxHost* host)
{
    g_realHost = host;
    Wrapper& w = g_wrappers[slot];
    if (!w.realSetHost || !host) return;

    g_wrappedHost            = *host;
    g_wrappedHost.fetchSuite = &wrappedFetchSuite;
    w.realSetHost(&g_wrappedHost);
}

template <int N> static void setHostThunk(OfxHost* host) { SetHostImpl(N, host); }

static void (*const kSetHosts[kMaxPlugins])(OfxHost*) = {
    &setHostThunk<0>, &setHostThunk<1>, &setHostThunk<2>, &setHostThunk<3>,
    &setHostThunk<4>, &setHostThunk<5>, &setHostThunk<6>, &setHostThunk<7>,
};

// ---------------------------------------------------------------- 加载官方插件
static void EnsureLoaded()
{
    if (g_real) return;

    wchar_t selfPath[MAX_PATH] = {};
    GetModuleFileNameW(g_self, selfPath, MAX_PATH);
    std::wstring dir(selfPath);
    const size_t pos = dir.find_last_of(L"\\/");
    if (pos != std::wstring::npos) dir.resize(pos + 1);

    WIN32_FIND_DATAW fd{};
    std::wstring pattern = dir + L"*_real.ofx";
    HANDLE h = FindFirstFileW(pattern.c_str(), &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            HMODULE m = LoadLibraryW((dir + fd.cFileName).c_str());
            if (m) { g_real = m; break; }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }

    if (!g_real) return;

    g_realGetNum    = reinterpret_cast<OfxGetNumFn>(GetProcAddress(g_real, "OfxGetNumberOfPlugins"));
    g_realGetPlugin = reinterpret_cast<OfxGetPluginFn>(GetProcAddress(g_real, "OfxGetPlugin"));
}

// ---------------------------------------------------------------- 导出
extern "C" {

OfxExport int OfxGetNumberOfPlugins(void)
{
    EnsureLoaded();
    return g_realGetNum ? g_realGetNum() : 0;
}

OfxExport OfxPlugin* OfxGetPlugin(int nth)
{
    EnsureLoaded();
    if (!g_realGetPlugin) return nullptr;

    OfxPlugin* real = g_realGetPlugin(nth);
    if (!real) return nullptr;
    if (nth < 0 || nth >= kMaxPlugins) return real;

    Wrapper& w = g_wrappers[nth];
    if (!w.used) {
        w.pub         = *real;
        w.realSetHost = real->setHost;
        w.pub.setHost = kSetHosts[nth];
        w.used        = true;
    }
    return &w.pub;
}

} // extern "C"

// ---------------------------------------------------------------- DllMain
BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) {
        g_self = module;
        DisableThreadLibraryCalls(module);
    }
    return TRUE;
}
