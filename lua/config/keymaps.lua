-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ==================== Copilot & Contest Mode Menu (<leader>t) ====================
local copilot_enabled = true

-- <leader>tc: Fast Contest Mode toggle
vim.keymap.set("n", "<leader>tc", function()
  local client_ok, client = pcall(require, "copilot.client")
  local is_disabled = client_ok and client.is_disabled and client.is_disabled()
  if is_disabled == nil then
    is_disabled = not copilot_enabled
  end

  if not is_disabled then
    vim.cmd("Copilot disable")
    copilot_enabled = false
    pcall(function()
      require("copilot.suggestion").clear_preview()
    end)
    vim.notify("Copilot disabled (Contest Mode: AI Off)", vim.log.levels.WARN, { title = "Contest Mode" })
  else
    vim.cmd("Copilot enable")
    copilot_enabled = true
    vim.notify("Copilot enabled (Ghost Suggestions Active)", vim.log.levels.INFO, { title = "Copilot" })
  end
end, { desc = "Toggle Copilot (Contest Mode)" })

-- <leader>ta: Toggle Auto-Trigger (Auto popup vs Manual on-demand)
vim.keymap.set("n", "<leader>ta", function()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok and suggestion.toggle_auto_trigger then
    suggestion.toggle_auto_trigger()
    local state = vim.b.copilot_suggestion_auto_trigger
    if state == false then
      vim.notify("Auto-trigger: OFF (Manual on-demand)", vim.log.levels.WARN, { title = "Copilot" })
    else
      vim.notify("Auto-trigger: ON (Inline ghost text)", vim.log.levels.INFO, { title = "Copilot" })
    end
  else
    vim.notify("Copilot suggestion module not loaded", vim.log.levels.ERROR, { title = "Copilot" })
  end
end, { desc = "Toggle Auto-Trigger" })

-- <leader>ts: Copilot Status (Auth, Connection, Model)
vim.keymap.set("n", "<leader>ts", function()
  vim.cmd("Copilot status")
end, { desc = "Copilot Status" })

-- <leader>tp: Suggestions Panel (10 alternatives)
vim.keymap.set("n", "<leader>tp", function()
  vim.cmd("Copilot panel")
end, { desc = "Copilot Suggestions Panel" })

-- <leader>te: Force Enable Copilot
vim.keymap.set("n", "<leader>te", function()
  vim.cmd("Copilot enable")
  copilot_enabled = true
  vim.notify("Copilot enabled", vim.log.levels.INFO, { title = "Copilot" })
end, { desc = "Enable Copilot" })

-- <leader>td: Force Disable Copilot
vim.keymap.set("n", "<leader>td", function()
  vim.cmd("Copilot disable")
  copilot_enabled = false
  pcall(function()
    require("copilot.suggestion").clear_preview()
  end)
  vim.notify("Copilot disabled", vim.log.levels.WARN, { title = "Copilot" })
end, { desc = "Disable Copilot" })

-- <leader>tr: Refresh / Trigger suggestion manually
vim.keymap.set("n", "<leader>tr", function()
  local client_ok, client = pcall(require, "copilot.client")
  local is_disabled = client_ok and client.is_disabled and client.is_disabled()
  if is_disabled == nil then
    is_disabled = not copilot_enabled
  end

  if is_disabled then
    vim.notify("Cannot trigger: Copilot is disabled (Contest Mode). Press <leader>tc to enable.", vim.log.levels.WARN, { title = "Contest Mode" })
    return
  end

  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok and suggestion.next then
    suggestion.next()
    vim.notify("Requested Copilot suggestion", vim.log.levels.INFO, { title = "Copilot" })
  end
end, { desc = "Trigger Copilot Suggestion" })

-- <leader>tl: Copilot Login (GitHub Device Code Flow)
local function copilot_login()
  local client_ok, client = pcall(require, "copilot.client")
  if client_ok and client.is_disabled and client.is_disabled() then
    vim.cmd("Copilot enable")
    copilot_enabled = true
  end
  vim.cmd("Copilot auth")
end

vim.keymap.set("n", "<leader>tl", copilot_login, { desc = "Copilot Login (GitHub Auth)" })

-- <leader>to: Copilot Logout (Sign Out)
local function copilot_logout()
  vim.cmd("Copilot auth signout")
  pcall(function()
    require("copilot.suggestion").clear_preview()
  end)
  vim.notify("Signed out of GitHub Copilot.", vim.log.levels.WARN, { title = "Copilot Logout" })
end

vim.keymap.set("n", "<leader>to", copilot_logout, { desc = "Copilot Logout (Sign Out)" })

-- Register WhichKey group description
pcall(function()
  local wk = require("which-key")
  wk.add({
    { "<leader>t", group = "Contest / Copilot" },
  })
end)

-- Find Files Across PC / Home (<leader><leader>)
vim.keymap.set("n", "<leader><leader>", function()
  Snacks.picker.files({ cwd = vim.fn.expand("~"), hidden = false })
end, { desc = "Find Files (PC / Home)" })

-- Interactive CP Snippets Picker (<leader>rt or rt)
local function open_snippets_picker()
  local json_path = vim.fn.expand("~/.config/nvim/snippets/cpp.json")
  if vim.fn.filereadable(json_path) == 0 then
    vim.notify("Snippets file not found", vim.log.levels.ERROR)
    return
  end
  local content = vim.fn.readfile(json_path)
  local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok or type(data) ~= "table" then
    vim.notify("Failed to parse snippets", vim.log.levels.ERROR)
    return
  end

  local items = {}
  for name, snippet in pairs(data) do
    local prefixes = type(snippet.prefix) == "table" and snippet.prefix or { snippet.prefix or "" }
    local prefix_str = table.concat(prefixes, ", ")
    local body_lines = type(snippet.body) == "table" and snippet.body or { snippet.body or "" }
    local body_text = table.concat(body_lines, "\n")
    local desc = snippet.description or name

    local preview_header = string.format("// %s\n// Trigger shortcut: %s\n// Description: %s\n// %s\n\n", name, prefix_str, desc, string.rep("-", 50))

    table.insert(items, {
      text = name .. " " .. prefix_str .. " " .. desc,
      name = name,
      prefix = prefix_str,
      desc = desc,
      body = body_text,
      preview = {
        text = preview_header .. body_text,
        ft = "cpp",
      },
    })
  end

  table.sort(items, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  Snacks.picker.pick({
    source = "snippets",
    title = "CP Snippets",
    items = items,
    format = function(item)
      return {
        { " ", "Special" },
        { " ", "Normal" },
        { string.format("%-28s", item.name), "Function" },
        { " ", "Normal" },
        { "[" .. item.prefix .. "]", "DiagnosticInfo" },
      }
    end,
    preview = "preview",
    layout = {
      preset = "default",
      width = 0.9,
      min_width = 110,
      height = 0.85,
    },
    actions = {
      confirm = function(picker, item)
        picker:close()
        if item and item.body then
          vim.schedule(function()
            if vim.snippet and vim.snippet.expand then
              vim.snippet.expand(item.body)
            else
              local lines = vim.split(item.body, "\n")
              vim.api.nvim_put(lines, "l", true, true)
            end
          end)
        end
      end,
    },
  })
end

vim.keymap.set("n", "<leader>rt", open_snippets_picker, { desc = "Browse & Insert CP Snippets" })
vim.keymap.set("n", "rt", open_snippets_picker, { desc = "Browse & Insert CP Snippets" })
vim.keymap.set("n", "<leader>sp", open_snippets_picker, { desc = "Browse & Insert CP Snippets" })
