require('hs.ipc')

hs.autoLaunch(false)
hs.automaticallyCheckForUpdates(false)

local sections = {
  {
    title = 'Applications',
    shortcuts = {
      { 'Fn', 'Dictate with Wispr Flow' },
      { '⌥ Return', 'Focus or open Kitty' },
      { '⌥ ⇧ Return', 'Open Herdr in Kitty' },
      { '⌥ S', 'Focus or open Zen' },
      { '⌘ E', 'Open Finder' },
    },
  },
  {
    title = 'Workspaces',
    shortcuts = {
      { '⌥ 1–4 / B / C', 'Switch workspace' },
      { '⌥ ⇧ 1–4 / B / C', 'Move window to workspace' },
      { '⌥ Tab', 'Previous workspace' },
      { '⌥ ⇧ Tab', 'Move workspace to next display' },
    },
  },
  {
    title = 'Windows',
    shortcuts = {
      { '⌥ H / J / K / L', 'Focus left / down / up / right' },
      { '⌥ ⇧ H / J / K / L', 'Move left / down / up / right' },
      { '⌃ ⌥ H / J / K / L', 'Join left / down / up / right' },
      { '⌥ F', 'Toggle fullscreen' },
      { '⌥ R', 'Flatten layout' },
      { '⌥ - / ,', 'Tile / accordion layout' },
      { '⌥ ß / ´', 'Resize by 50 px' },
      { '⌃ ⌥ Delete', 'Close all other windows' },
    },
  },
  {
    title = 'Terminal',
    shortcuts = {
      { '⌃ R', 'Fuzzy history search' },
      { '⌃ F', 'Fuzzy file search' },
      { '⌃ T', 'Fuzzy file search including hidden files' },
      { '↑ / ↓', 'Search matching history' },
      { 'Esc', 'Enter vi command mode' },
    },
  },
  {
    title = 'Neovim',
    shortcuts = {
      { 'Esc', 'Save file' },
      { '⌃ A', 'Select all' },
      { 'Space E', 'File browser' },
      { 'Space F', 'Find files' },
      { 'Space S', 'Search text' },
      { 'Space B', 'List buffers' },
      { 'Space G', 'Open Neogit' },
      { 'g d', 'Go to definition' },
      { 'Visual P', 'Paste without replacing register' },
    },
  },
  {
    title = 'Capture',
    shortcuts = {
      { '⌘ ⇧ 3', 'Capture region to screenshots' },
      { '⌘ ⇧ 4', 'Capture region to clipboard' },
      { '⌘ ⇧ 5', 'Open capture controls' },
    },
  },
  {
    title = 'Herdr',
    shortcuts = {
      { '⌃ B, P / N', 'Previous / next tab' },
      { '⌃ B, 1–9', 'Switch to tab' },
      { '⌃ B, C', 'Create tab' },
      { '⌃ B, "', 'Split horizontally' },
      { '⌃ B, %', 'Split vertically' },
    },
  },
}

local function escapeHtml(value)
  return value
    :gsub('&', '&amp;')
    :gsub('<', '&lt;')
    :gsub('>', '&gt;')
    :gsub('"', '&quot;')
end

local function renderSections()
  local output = {}
  for _, section in ipairs(sections) do
    local rows = {}
    for _, shortcut in ipairs(section.shortcuts) do
      table.insert(rows, string.format(
        '<div class="row"><kbd>%s</kbd><span>%s</span></div>',
        escapeHtml(shortcut[1]),
        escapeHtml(shortcut[2])
      ))
    end
    table.insert(output, string.format(
      '<section><h2>%s</h2>%s</section>',
      escapeHtml(section.title),
      table.concat(rows)
    ))
  end
  return table.concat(output)
end

local html = [[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; }
  html, body { width: 100%; height: 100%; margin: 0; background: transparent; }
  body {
    position: relative;
    isolation: isolate;
    overflow: hidden;
    border-radius: 22px;
    clip-path: inset(0 round 22px);
    color: #e8e6e3;
    background: radial-gradient(circle at top, rgba(86, 31, 43, 0.72), rgba(18, 16, 20, 0.8) 36%);
    -webkit-backdrop-filter: blur(28px) saturate(135%);
    backdrop-filter: blur(28px) saturate(135%);
    border: 1px solid rgba(255, 64, 87, 0.48);
    box-shadow: inset 0 1px rgba(255, 255, 255, 0.08);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  main { padding: 28px 32px 24px; }
  header { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 22px; }
  h1 { margin: 0; font-size: 25px; font-weight: 700; letter-spacing: -0.4px; }
  header span { color: #aaa3aa; font-size: 13px; }
  .grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 20px 22px; }
  section { min-width: 0; }
  h2 {
    color: #ff4057;
    margin: 0 0 8px;
    font-size: 11px;
    font-weight: 750;
    letter-spacing: 1.25px;
    text-transform: uppercase;
  }
  .row {
    display: grid;
    grid-template-columns: minmax(96px, auto) 1fr;
    align-items: center;
    gap: 10px;
    min-height: 30px;
    border-top: 1px solid rgba(255, 255, 255, 0.055);
  }
  kbd {
    color: #fff8f9;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
    font-size: 12px;
    font-weight: 650;
    white-space: nowrap;
  }
  .row span { color: #bdb7bd; font-size: 12px; line-height: 1.2; }
</style>
</head>
<body>
<main>
  <header><h1>Keyboard shortcuts</h1><span>Release Option or Escape to close</span></header>
  <div class="grid">{{SECTIONS}}</div>
</main>
</body>
</html>
]]

local overlay
local holdTimer

local function overlayFrame()
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local frame = screen:frame()
  local width = math.min(1280, frame.w - 64)
  local height = math.min(650, frame.h - 80)
  return {
    x = frame.x + (frame.w - width) / 2,
    y = frame.y + (frame.h - height) / 2,
    w = width,
    h = height,
  }
end

local function showOverlay()
  if not overlay then
    overlay = hs.webview.new(overlayFrame(), {
      javaScriptEnabled = false,
      javaScriptCanOpenWindowsAutomatically = false,
      privateBrowsing = true,
    })
      :windowStyle(0)
      :allowTextEntry(false)
      :allowGestures(false)
      :transparent(true)
      :shadow(false)
      :html((html:gsub('{{SECTIONS}}', function() return renderSections() end)))
  else
    overlay:frame(overlayFrame())
  end
  overlay:show():bringToFront(true)
end

local function hideOverlay()
  if holdTimer then
    holdTimer:stop()
    holdTimer = nil
  end
  if overlay then
    overlay:hide()
  end
end

local function startHold()
  hideOverlay()
  holdTimer = hs.timer.doAfter(0.25, function()
    holdTimer = nil
    showOverlay()
  end)
end

shortcutOverlayHotkey = hs.hotkey.bind({ 'alt' }, 'escape', startHold, hideOverlay)
shortcutOverlay = { show = showOverlay, hide = hideOverlay }

configWatcher = hs.pathwatcher.new(hs.configdir, function(files)
  for _, file in ipairs(files) do
    if file:match('%.lua$') then
      hs.reload()
      return
    end
  end
end):start()
