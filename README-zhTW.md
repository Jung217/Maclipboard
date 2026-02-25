# Maclipboard
> **README in [English](https://github.com/Jung217/Maclipboard/blob/main/README.md)**

> 一款專為 macOS 打造的輕量、快速且極簡的剪貼簿管理器，完全使用 SwiftUI 開發。它在背景無形運行，記錄您所有的剪貼簿歷史，讓您能快速存取並自動貼上先前複製的內容。

<img src="public/AppIcon-modified.png" alt="AppIcon" style="width:30%;">

## 💡 為什麼選擇 Maclipboard？
與其他同類產品相比，Maclipboard **極其輕量（麻雀雖小五臟俱全）**，擁有**更原生的 Apple UI**，並提供**更直覺的使用者體驗與快速鍵**。

## ✨ 功能特色

- **全域快速鍵存取**：在任何應用程式中按下 <kbd>CONTROL (⌃)</kbd> + <kbd>V</kbd> 即可立即喚出剪貼簿歷史。
- **鍵盤驅動的自動貼上**：使用 <kbd>UP (↑)</kbd> 與 <kbd>DOWN (↓)</kbd> 方向鍵瀏覽歷史紀錄並按下 <kbd>RETURN (⏎)</kbd>，或直接點擊項目，即可自動貼上至您當前的活動視窗。
- **釘選功能**：將滑鼠懸停在任何剪貼簿項目上並點擊「圖釘」圖示，即可將最常用的內容永久鎖定在歷史紀錄頂部。
- **分頁切換**：使用 <kbd>LEFT (←)</kbd> 與 <kbd>RIGHT (→)</kbd> 方向鍵，即可快速在完整的剪貼簿歷史與僅顯示釘選項目的分頁之間進行切換。
- **進階操作熱鍵**：使用方向鍵選取項目時：
  - <kbd>SPACE</kbd>：開啟該項目的完整純文字預覽視窗。
  - <kbd>CONTROL (⌃)</kbd> + <kbd>P</kbd>：直接透過鍵盤切換該項目的釘選狀態。
  - <kbd>COMMAND (⌘)</kbd> + <kbd>BACKSPACE (⌫)</kbd>：將該項目從歷史紀錄中永久刪除。
- **豐富的媒體支援**：Maclipboard 不僅僅支援文字！
  - **檔案**：從 Finder 中直接複製檔案與資料夾（透過路徑），顯示原生文件圖示，並允許您將其自動貼上至任何地方。
  - **原生螢幕快照**：在背景靜默監控您的 `~/Desktop`（桌面）資料夾。當您使用 macOS 原生截圖捷徑（`Cmd+Shift+4` 或 `Cmd+Shift+5`）時，Maclipboard 會攔截新圖片並立即加入到剪貼簿歷史中！
- **豐富的自訂選項**：點擊面板頂部的「齒輪」圖示以存取原生設定：
  - **外觀主題**：強制使用淺色模式、深色模式，或動態跟隨 macOS 系統設定。
  - **背景圖片**：從您的 Mac 中選擇任何本地圖片，自動延展並填滿面板背景。
  - **透明度與模糊控制**：調整背景透明度滑桿，並可選用毛玻璃模糊效果，動態過濾您選擇的背景圖片或顏色。
  - **自訂顏色**：使用 macOS 原生調色盤為面板背景挑選特定的色調。
  - **行為控制**：啟用「登入時啟動（Launch at Login）」以自動執行，或開啟「離開時清除紀錄（Clear History on Quit）」以保護隱私。

## 🚀 安裝與使用

### 1. 下載預先編譯的安裝檔（最快）
您可以直接從 [GitHub Releases](https://github.com/Jung217/Maclipboard/releases) 頁面下載最新的 `.dmg` 安裝檔。開啟下載的檔案，並將 Maclipboard 應用程式拖曳至提供的 `Applications`（應用程式）資料夾捷徑中！

### 2. 從原始碼編譯

Maclipboard 完全原生開發，不需要任何笨重的 JavaScript 依賴套件。如果您偏好從原始碼編譯應用程式，本專案提供了一個方便的 `Makefile`。

#### 系統需求
- macOS 13.0 或更新版本。
- 已安裝 [Xcode Command Line Tools](https://developer.apple.com/xcode/features/)。（您可以透過在終端機中執行 `xcode-select --install` 來安裝）。

#### 執行應用程式
1. 開啟終端機並導覽至本專案的根資料夾。
2. 執行以下指令以立即編譯並啟動應用程式：
   ```bash
   make run
   ```
3. 或者，如果您只想將 `Maclipboard.app` 軟體包編譯至 `build/` 資料夾而不啟動它，請執行：
   ```bash
   make app
   ```
4. 若要建立拖曳安裝的 DMG 檔案，請執行：
   ```bash
   make dmg
   ```
   *(需要 `create-dmg`，可透過 `brew install create-dmg` 安裝)*
5. 若要清理編譯目錄並重新開始，請執行：
   ```bash
   make clean
   ```

## ⚙️ 權限疑難排解

由於 Maclipboard 在背景執行時需要監聽全域的 <kbd>CONTROL (⌃)</kbd> + <kbd>V</kbd> 快速鍵，並為了「自動貼上」功能模擬 <kbd>COMMAND (⌘)</kbd> + <kbd>V</kbd> 鍵盤輸入，因此它嚴格要求 macOS 的**輔助使用（Accessibility）權限**。

此外，為提供「原生螢幕快照」支援（`Cmd+Shift+4` / `Cmd+Shift+5`），Maclipboard 需要 **「桌面（Desktop）資料夾」的存取權限**。這樣當 macOS 在您的桌面上產生新的截圖時，Maclipboard 就能偵測並將其無縫讀入到您的剪貼簿歷史中。

**如果按下快速鍵並未開啟面板，或者點擊項目並未能將其貼上至您當前的應用程式中：**
1. 開啟 **「系統設定」** > **「隱私權與安全性」** > **「輔助使用」**。
2. 在應用程式清單中找到 `Maclipboard`。
3. 確保 `Maclipboard` 旁邊的切換開關已開啟（**ON**）。

*注意：如果已授予權限但應用程式仍沒有反應（這在從原始碼頻繁重新編譯應用程式時很常見），macOS 可能快取了舊的簽章。在「輔助使用」清單中選擇 `Maclipboard`，點擊減號（`-`）按鈕將其完全移除，然後再次執行 `make run`，以觸發作業系統全新的權限請求對話方塊。*
