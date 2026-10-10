-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle GitHub Copilot ON/OFF (Contest Mode)
local copilot_enabled = true
vim.keymap.set("n", "<leader>tc", function()
  if copilot_enabled then
    vim.cmd("Copilot disable")
    copilot_enabled = false
    vim.notify("Copilot disabled (Contest Mode)", vim.log.levels.WARN, { title = "Copilot" })
  else
    vim.cmd("Copilot enable")
    copilot_enabled = true
    vim.notify("Copilot enabled", vim.log.levels.INFO, { title = "Copilot" })
  end
end, { desc = "Toggle Copilot (Contest Mode)" })

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
