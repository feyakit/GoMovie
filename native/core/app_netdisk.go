package core

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"gomovie/native/core/netdisk"
)

// 网盘通道：扫码登录 + 分享解析 + 直链播放 + 统一站源桥接。
// 凭据只存应用私有目录（netdisk-cookies.json，0600），不上传任何服务。

type netdiskRuntime struct {
	once  sync.Once
	store *netdisk.Store
	login *netdisk.LoginManager
	err   error
	dir   string
}

var (
	netdiskMu sync.Mutex
	netdiskRT *netdiskRuntime
)

func init() {
	Register(SourceDescriptor{
		ID:                 "netdisk",
		Name:               "网盘分享",
		Description:        "粘贴夸克网盘分享链接解析选集并直链播放",
		Group:              "netdisk",
		GroupName:          "网盘直达",
		SkipVIPPrompt:      true,
		AllowEmptyCatalog:  true,
		KeepDetailEpisodes: true,
		NoHostRotation:     true,
	}, func(Host) Provider {
		return &netdiskProvider{}
	})
}

func (engine *nativeEngine) netdiskInit() (*netdiskRuntime, error) {
	netdiskMu.Lock()
	dir := engine.directory
	netdiskMu.Unlock()

	netdiskMu.Lock()
	defer netdiskMu.Unlock()
	if netdiskRT != nil && netdiskRT.dir == dir && netdiskRT.err == nil {
		return netdiskRT, nil
	}
	rt := &netdiskRuntime{dir: filepath.Clean(dir)}
	if rt.dir == "" || rt.dir == "." {
		rt.err = errors.New("应用目录尚未就绪")
		netdiskRT = rt
		return nil, rt.err
	}
	rt.store = netdisk.NewStore(rt.dir)
	rt.login = netdisk.NewLoginManager(rt.store)
	netdiskRT = rt
	return rt, nil
}

// netdiskStatus 返回各网盘登录状态与临时目录说明。
func (engine *nativeEngine) netdiskStatus() (map[string]any, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return nil, err
	}
	status := rt.store.Status()
	ready := map[string]bool{}
	for name := range status {
		creds, err := rt.store.Get(name)
		ready[name] = err == nil && netdisk.ProviderReady(creds)
	}
	return map[string]any{"loggedIn": status, "ready": ready}, nil
}

// netdiskLoginStart 生成扫码登录二维码。
func (engine *nativeEngine) netdiskLoginStart(ctx context.Context) (any, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return nil, err
	}
	return rt.login.Start(ctx)
}

// netdiskLoginPoll 查询扫码结果。
func (engine *nativeEngine) netdiskLoginPoll(ctx context.Context, id string) (any, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return nil, err
	}
	return rt.login.Poll(ctx, id)
}

// netdiskLogout 清除本地凭据。
func (engine *nativeEngine) netdiskLogout(provider string) (bool, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return false, err
	}
	if provider == "" {
		provider = "quark"
	}
	return true, rt.store.Clear(provider)
}

func (engine *nativeEngine) netdiskSetCookie(provider, rawCookie string) (bool, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return false, err
	}
	if provider != "quark" && provider != "uc" {
		return false, errors.New("不支持的网盘类型")
	}
	cookies := make([]netdisk.Cookie, 0)
	for _, part := range strings.Split(rawCookie, ";") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		name, value, ok := strings.Cut(part, "=")
		name = strings.TrimSpace(name)
		value = strings.TrimSpace(value)
		if !ok || name == "" || value == "" {
			continue
		}
		cookies = append(cookies, netdisk.Cookie{Name: name, Value: value})
	}
	creds := &netdisk.Credentials{
		Provider: provider,
		Cookies:  cookies,
		SavedAt:  time.Now().Unix(),
	}
	if !netdisk.ProviderReady(creds) {
		return false, errors.New("Cookie 不完整（缺少 __puus），请从网页端复制完整 Cookie")
	}
	if err := rt.store.Put(creds); err != nil {
		return false, err
	}
	return true, nil
}

func (engine *nativeEngine) netdiskClientFor(raw string) (*netdisk.Quark, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return nil, err
	}
	provider := netdisk.DetectProvider(raw)
	if provider == "uc" {
		creds, err := rt.store.Get("uc")
		if err != nil || !netdisk.ProviderReady(creds) {
			creds, _ = rt.store.Get("quark")
		}
		return netdisk.NewUC(creds), nil
	}
	creds, err := rt.store.Get("quark")
	if err != nil {
		return netdisk.NewQuark(nil), nil
	}
	return netdisk.NewQuark(creds), nil
}

// netdiskShare 解析分享链接，返回剧集列表。
func (engine *nativeEngine) netdiskShare(ctx context.Context, raw string) (any, error) {
	if raw == "" {
		return nil, errors.New("请填写网盘分享链接")
	}
	client, err := engine.netdiskClientFor(raw)
	if err != nil {
		return nil, err
	}
	return client.Share(ctx, raw)
}

// netdiskOpenShare 将分享链接解析为标准 Drama 与 Chapter 列表，供统一详情页和主播放器使用。
func (engine *nativeEngine) netdiskOpenShare(ctx context.Context, raw string) (map[string]any, error) {
	shareURL := netdisk.ExtractShareURL(raw)
	if shareURL == "" {
		shareURL = strings.TrimSpace(raw)
	}
	if shareURL == "" {
		return nil, errors.New("请填写网盘分享链接")
	}
	client, err := engine.netdiskClientFor(shareURL)
	if err != nil {
		return nil, err
	}
	info, err := client.Share(ctx, shareURL)
	if err != nil {
		return nil, err
	}
	drama, chapters := shareInfoToDrama("netdisk", shareURL, info)
	badge := "夸克网盘"
	if info.Provider == "uc" {
		badge = "UC网盘"
	}
	libDrama := LibraryDrama{
		ID:            drama.ID,
		Source:        "netdisk",
		SourceID:      shareURL,
		Title:         drama.Title,
		Description:   drama.Desc,
		Episodes:      len(chapters),
		Category:      "网盘分享",
		Badge:         badge,
		ReleaseStatus: "已完结",
	}
	return map[string]any{
		"drama":    libDrama,
		"chapters": chapters,
		"loggedIn": info.LoggedIn,
	}, nil
}

// netdiskPlay 把指定集转存并取回播放地址（含播放所需请求头）。
func (engine *nativeEngine) netdiskPlay(ctx context.Context, raw string, index int) (any, error) {
	if raw == "" {
		return nil, errors.New("请填写网盘分享链接")
	}
	client, err := engine.netdiskClientFor(raw)
	if err != nil {
		return nil, err
	}
	return client.ResolveShare(ctx, raw, index)
}

// netdiskCleanup 清理网盘临时转存目录（gomovie_tmp）。
func (engine *nativeEngine) netdiskCleanup(ctx context.Context) (map[string]any, error) {
	rt, err := engine.netdiskInit()
	if err != nil {
		return nil, err
	}
	total := 0
	cleanedAny := false
	var firstErr error
	for _, provider := range []string{"quark", "uc"} {
		creds, getErr := rt.store.Get(provider)
		if getErr != nil || !netdisk.ProviderReady(creds) {
			continue
		}
		cleanedAny = true
		var client *netdisk.Quark
		if provider == "uc" {
			client = netdisk.NewUC(creds)
		} else {
			client = netdisk.NewQuark(creds)
		}
		deleted, cleanErr := client.CleanupTemp(ctx)
		if cleanErr != nil {
			if firstErr == nil {
				firstErr = cleanErr
			}
			continue
		}
		total += deleted
	}
	if !cleanedAny {
		return nil, netdisk.ErrNotLoggedIn
	}
	if firstErr != nil && total == 0 {
		return nil, firstErr
	}
	return map[string]any{"deleted": total, "tempDir": "gomovie_tmp"}, nil
}

// netdiskInfo 返回临时目录说明。
func (engine *nativeEngine) netdiskInfo() map[string]any {
	return map[string]any{
		"tempDir": "gomovie_tmp",
		"note":    "转存的文件会放在网盘根目录的 gomovie_tmp 下，可随时一键清理",
	}
}

func formatNetdiskSize(bytes int64) string {
	if bytes <= 0 {
		return ""
	}
	const gb = 1024 * 1024 * 1024
	const mb = 1024 * 1024
	if bytes >= gb {
		return fmt.Sprintf("%.2fGB", float64(bytes)/float64(gb))
	}
	if bytes >= mb {
		return fmt.Sprintf("%dMB", bytes/mb)
	}
	return ""
}

func formatNetdiskEpisodeTitle(name string, size int64) string {
	trimmed := strings.TrimSpace(name)
	sizeText := formatNetdiskSize(size)
	if sizeText == "" {
		return trimmed
	}
	if strings.HasPrefix(trimmed, "[") {
		return trimmed
	}
	if trimmed == "" {
		return "[" + sizeText + "]"
	}
	return "[" + sizeText + "] " + trimmed
}

func shareInfoToDrama(source, shareURL string, info *netdisk.ShareInfo) (Drama, []Chapter) {
	title := strings.TrimSpace(info.Title)
	if title == "" {
		prefix := "夸克分享"
		if info.Provider == "uc" {
			prefix = "UC分享"
		}
		title = prefix + " (" + info.ShareID + ")"
	}
	badge := "夸克网盘"
	if info.Provider == "uc" {
		badge = "UC网盘"
	}
	drama := Drama{
		ID:       source + ":" + shareURL,
		Source:   source,
		SourceID: shareURL,
		Title:    title,
		Desc:     "网盘分享 · 共 " + strconv.Itoa(len(info.Episodes)) + " 集",
		Badge:    badge,
	}
	chapters := make([]Chapter, 0, len(info.Episodes))
	for i, ep := range info.Episodes {
		epTitle := formatNetdiskEpisodeTitle(ep.Name, ep.Size)
		epNum, _ := json.Marshal(i + 1)
		chapters = append(chapters, Chapter{
			ID:             drama.ID + "#" + strconv.Itoa(i),
			Source:         source,
			Title:          epTitle,
			VideoURL:       encodeNetdiskVideoRef(i, shareURL),
			CurrentEpisode: epNum,
			MediaSize:      ep.Size,
		})
	}
	return drama, chapters
}

func encodeNetdiskVideoRef(index int, shareURL string) string {
	return "netdisk:" + strconv.Itoa(index) + "|" + shareURL
}

func decodeNetdiskVideoRef(raw string) (int, string, bool) {
	trimmed := strings.TrimSpace(raw)
	if strings.HasPrefix(trimmed, "netdisk:") {
		rest := strings.TrimPrefix(trimmed, "netdisk:")
		if idxStr, shareURL, ok := strings.Cut(rest, "|"); ok {
			idx, err := strconv.Atoi(idxStr)
			if err == nil && shareURL != "" {
				return idx, shareURL, true
			}
		}
	}
	if shareURL := netdisk.ExtractShareURL(trimmed); shareURL != "" {
		return 0, shareURL, true
	}
	return 0, "", false
}

func resolveNetdiskMedia(ctx context.Context, rawVideoURL string) (ProviderMedia, error) {
	idx, shareURL, ok := decodeNetdiskVideoRef(rawVideoURL)
	if !ok {
		return ProviderMedia{}, errors.New("无效的网盘播放引用")
	}
	netdiskMu.Lock()
	rt := netdiskRT
	netdiskMu.Unlock()
	if rt == nil || rt.store == nil {
		return ProviderMedia{}, errors.New("网盘模块尚未初始化")
	}
	provider := netdisk.DetectProvider(shareURL)
	if provider != "uc" {
		provider = "quark"
	}
	creds, err := rt.store.Get(provider)
	if err != nil {
		if provider == "uc" {
			return ProviderMedia{}, errors.New("UC 网盘未登录，请先在网盘页配置 Cookie")
		}
		return ProviderMedia{}, netdisk.ErrNotLoggedIn
	}
	if !netdisk.ProviderReady(creds) {
		if provider == "uc" {
			return ProviderMedia{}, errors.New("UC 网盘登录态不完整，请重新配置 Cookie")
		}
		return ProviderMedia{}, errors.New("网盘登录态不完整，请先扫码登录夸克")
	}
	var client *netdisk.Quark
	defaultReferer := "https://pan.quark.cn/"
	if provider == "uc" {
		client = netdisk.NewUC(creds)
		defaultReferer = "https://drive.uc.cn/"
	} else {
		client = netdisk.NewQuark(creds)
	}
	play, err := client.ResolveShare(ctx, shareURL, idx)
	if err != nil {
		return ProviderMedia{}, err
	}
	parsed, _ := url.Parse(play.URL)
	ua := play.Headers["User-Agent"]
	if ua == "" {
		ua = UserAgent
	}
	referer := play.Headers["Referer"]
	if referer == "" {
		referer = defaultReferer
	}
	return ProviderMedia{
		URL:     play.URL,
		Referer: referer,
		Credentials: &MediaCredentials{
			Cookie:    play.Headers["Cookie"],
			Origin:    ProviderMediaOrigin(parsed),
			Referer:   referer,
			UserAgent: ua,
		},
	}, nil
}

type netdiskProvider struct{}

func (p *netdiskProvider) Descriptor() SourceDescriptor {
	desc, _ := registeredDescriptor("netdisk")
	return desc
}

func (p *netdiskProvider) Categories(context.Context, bool) ([]Category, error) {
	return []Category{{ID: "all", Name: "全部"}}, nil
}

func (p *netdiskProvider) CatalogPage(context.Context, int, string) ([]Drama, bool, error) {
	return []Drama{}, false, nil
}

func (p *netdiskProvider) Detail(ctx context.Context, sourceID string) (Drama, []Chapter, error) {
	netdiskMu.Lock()
	rt := netdiskRT
	netdiskMu.Unlock()
	provider := netdisk.DetectProvider(sourceID)
	if provider != "uc" {
		provider = "quark"
	}
	var creds *netdisk.Credentials
	if rt != nil && rt.store != nil {
		creds, _ = rt.store.Get(provider)
	}
	var client *netdisk.Quark
	if provider == "uc" {
		client = netdisk.NewUC(creds)
	} else {
		client = netdisk.NewQuark(creds)
	}
	info, err := client.Share(ctx, sourceID)
	if err != nil {
		return Drama{}, nil, err
	}
	drama, chapters := shareInfoToDrama("netdisk", sourceID, info)
	return drama, chapters, nil
}

func (p *netdiskProvider) ResolveMedia(ctx context.Context, task Task) (ProviderMedia, error) {
	return resolveNetdiskMedia(ctx, task.Chapter.VideoURL)
}
