#!/bin/bash
echo "卸载 Cookie Saver Native Host..."
rm -f "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.biscuitbox.host.json"
rm -f "$HOME/Library/Application Support/Chromium/NativeMessagingHosts/com.biscuitbox.host.json"
rm -f "$HOME/.config/google-chrome/NativeMessagingHosts/com.biscuitbox.host.json"
rm -f "$HOME/.config/chromium/NativeMessagingHosts/com.biscuitbox.host.json"

# Windows 注册表清理（通过 PowerShell）
if command -v powershell.exe &>/dev/null; then
    powershell.exe -Command "Remove-Item 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.biscuitbox.host' -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
fi
echo "✅ 已卸载"
