// Cookie Saver - Native Messaging Host (Go 实现)
//
// Native Messaging 协议：
// - stdin/stdout 通信
// - 前 4 字节为小端序 uint32 表示消息长度
// - 后续为 UTF-8 JSON 数据

package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
)

// Chrome 扩展发来的请求
type nativeRequest struct {
	Value      string `json:"value"`
	Domain     string `json:"domain,omitempty"`
	CookieName string `json:"cookieName,omitempty"`
	SavePath   string `json:"savePath,omitempty"`
}

// 返回给 Chrome 扩展的响应
type nativeResponse struct {
	Message string `json:"message"`
	Path    string `json:"path,omitempty"`
	Error   bool   `json:"error,omitempty"`
}

// 写入到本地文件的元数据结构
type savedCookie struct {
	Value      string `json:"value"`
	Domain     string `json:"domain"`
	CookieName string `json:"cookieName"`
}

func getCacheDir() string {
	var base string
	switch runtime.GOOS {
	case "windows":
		base = os.Getenv("LOCALAPPDATA")
		if base == "" {
			base = os.Getenv("USERPROFILE")
		}
		return filepath.Join(base, "biscuit-box")
	case "darwin":
		return filepath.Join(os.Getenv("HOME"), "Library", "Caches", "biscuit-box")
	default: // linux
		base = os.Getenv("XDG_CACHE_HOME")
		if base == "" {
			base = filepath.Join(os.Getenv("HOME"), ".cache")
		}
		return filepath.Join(base, "biscuit-box")
	}
}

func getTokenPath() string {
	return filepath.Join(getCacheDir(), "cookie_token")
}

func getMetaPath() string {
	return filepath.Join(getCacheDir(), "cookie_meta.json")
}

// readNativeMessage 从 stdin 读取一条 Native Messaging 消息
func readNativeMessage() (*nativeRequest, error) {
	// 读取 4 字节长度前缀（小端序 uint32）
	var length uint32
	if err := binary.Read(os.Stdin, binary.LittleEndian, &length); err != nil {
		return nil, err
	}
	if length > 1<<20 { // 最大 1MB
		return nil, fmt.Errorf("消息过大: %d bytes", length)
	}

	// 读取 JSON 数据
	data := make([]byte, length)
	if _, err := io.ReadFull(os.Stdin, data); err != nil {
		return nil, err
	}

	var req nativeRequest
	if err := json.Unmarshal(data, &req); err != nil {
		return nil, fmt.Errorf("JSON 解析失败: %w", err)
	}
	return &req, nil
}

// writeNativeMessage 向 stdout 写入一条 Native Messaging 消息
func writeNativeMessage(resp *nativeResponse) error {
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}

	// 写入 4 字节长度前缀
	if err := binary.Write(os.Stdout, binary.LittleEndian, uint32(len(data))); err != nil {
		return err
	}
	// 写入 JSON 数据
	if _, err := os.Stdout.Write(data); err != nil {
		return err
	}
	return nil
}

func expandHome(path string) string {
	if len(path) > 1 && path[0] == '~' {
		home, err := os.UserHomeDir()
		if err == nil {
			return filepath.Join(home, path[1:])
		}
	}
	return path
}

func saveCookie(req *nativeRequest) *nativeResponse {
	// 确定保存路径
	tokenPath := req.SavePath
	if tokenPath == "" {
		cacheDir := getCacheDir()
		if err := os.MkdirAll(cacheDir, 0755); err != nil {
			return &nativeResponse{
				Message: fmt.Sprintf("创建缓存目录失败: %v", err),
				Error:   true,
			}
		}
		tokenPath = getTokenPath()
	}

	tokenPath = expandHome(tokenPath)

	// 确保目标目录存在
	dir := filepath.Dir(tokenPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return &nativeResponse{
			Message: fmt.Sprintf("创建目录失败: %v", err),
			Error:   true,
		}
	}

	// 写入 Cookie 原始值
	if err := os.WriteFile(tokenPath, []byte(req.Value), 0600); err != nil {
		return &nativeResponse{
			Message: fmt.Sprintf("写入 Cookie 失败: %v", err),
			Error:   true,
		}
	}

	// 写入元数据 JSON（包含域名和键名，方便 AI 识别）
	if req.Domain != "" || req.CookieName != "" {
		meta := savedCookie{
			Value:      req.Value,
			Domain:     req.Domain,
			CookieName: req.CookieName,
		}
		metaData, _ := json.MarshalIndent(meta, "", "  ")
		metaPath := filepath.Join(filepath.Dir(tokenPath), "cookie_meta.json")
		_ = os.WriteFile(metaPath, metaData, 0600)
	}

	return &nativeResponse{
		Message: fmt.Sprintf("Cookie 已保存到: %s", tokenPath),
		Path:    tokenPath,
	}
}

func main() {
	// Windows 需要二进制模式
	if runtime.GOOS == "windows" {
		// Go 的 os.Stdin/os.Stdout 在 Windows 下默认就是二进制模式，无需额外处理
	}

	// Native Messaging 是长连接，循环处理消息
	for {
		req, err := readNativeMessage()
		if err != nil {
			if err == io.EOF {
				break
			}
			_ = writeNativeMessage(&nativeResponse{
				Message: fmt.Sprintf("读取消息失败: %v", err),
				Error:   true,
			})
			continue
		}

		// ping 健康检查
		if req.Value == "__ping__" {
			_ = writeNativeMessage(&nativeResponse{
				Message: "pong",
			})
			continue
		}

		if req.Value == "" {
			_ = writeNativeMessage(&nativeResponse{
				Message: "未收到有效的 Cookie 值",
				Error:   true,
			})
			continue
		}

		resp := saveCookie(req)
		_ = writeNativeMessage(resp)
	}
}
