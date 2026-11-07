-- ==============================================================================
-- Asynchronous Git Update Checker for Neovim Configuration
-- ==============================================================================
local M = {}

-- State storage in ~/.local/state/nvim/git_update_state.json
local function get_state_file()
  local state_dir = vim.fn.stdpath("state")
  pcall(vim.fn.mkdir, state_dir, "p")
  return state_dir .. "/git_update_state.json"
end

local function read_state()
  local file = get_state_file()
  if vim.fn.filereadable(file) == 1 then
    local content = table.concat(vim.fn.readfile(file), "")
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
      return data
    end
  end
  return {}
end

local function write_state(data)
  local file = get_state_file()
  local encoded = vim.json.encode(data)
  pcall(vim.fn.writefile, { encoded }, file)
end

-- Checks for remote updates in the configuration repository.
-- Throttled to once every 4 hours unless force is true.
function M.check_for_updates(force)
  local config_dir = vim.fn.stdpath("config")
  if vim.fn.isdirectory(config_dir .. "/.git") ~= 1 then
    return
  end

  local now = os.time()
  local state = read_state()
  local last_fetch = tonumber(state.last_fetch_time) or 0

  -- 4 hours = 14400 seconds throttle for background network fetch
  if not force and (now - last_fetch) < 14400 then
    return
  end

  -- 1. Check if an upstream tracking branch is configured
  vim.system(
    { "git", "-C", config_dir, "rev-parse", "--abbrev-ref", "@{u}" },
    { text = true },
    function(track_obj)
      if track_obj.code ~= 0 or not track_obj.stdout or vim.trim(track_obj.stdout) == "" then
        return
      end

      -- 2. Fetch remote silently in background (non-blocking, 8s timeout, no terminal prompts)
      vim.system(
        { "git", "-C", config_dir, "fetch", "--quiet" },
        {
          text = true,
          timeout = 8000,
          env = { GIT_TERMINAL_PROMPT = "0" },
        },
        function(fetch_obj)
          if fetch_obj.code ~= 0 then
            -- Network offline or fetch error: fail silently without nagging
            return
          end

          state.last_fetch_time = os.time()
          write_state(state)

          -- 3. Check git status to see if behind upstream
          vim.system(
            { "git", "-C", config_dir, "status", "-sb", "-uno" },
            { text = true },
            function(status_obj)
              local count = 0
              if status_obj.code == 0 and status_obj.stdout then
                local first_line = status_obj.stdout:match("^[^\r\n]+") or ""
                local behind_match = first_line:match("%[.*behind%s+(%d+)")
                if behind_match then
                  count = tonumber(behind_match) or 0
                end
              end

              -- Fallback to rev-list if status header was ambiguous
              if count == 0 and status_obj.code == 0 then
                vim.system(
                  { "git", "-C", config_dir, "rev-list", "HEAD..@{u}", "--count" },
                  { text = true },
                  function(rev_obj)
                    if rev_obj.code == 0 and rev_obj.stdout then
                      count = tonumber(vim.trim(rev_obj.stdout)) or 0
                    end
                    if count > 0 then
                      vim.schedule(function()
                        local commit_text = (count == 1) and "1 new commit" or string.format("%d new commits", count)
                        local msg = string.format("📦 %s available for ~/.config/nvim!\nRun: git -C ~/.config/nvim pull (or :CpPull)", commit_text)
                        vim.notify(msg, vim.log.levels.INFO, { title = "Config Update Available" })
                      end)
                    elseif force then
                      vim.schedule(function()
                        vim.notify("✅ Configuration is up to date with remote.", vim.log.levels.INFO, { title = "Config Update" })
                      end)
                    end
                  end
                )
                return
              end

              if count > 0 then
                vim.schedule(function()
                  local commit_text = (count == 1) and "1 new commit" or string.format("%d new commits", count)
                  local msg = string.format("📦 %s available for ~/.config/nvim!\nRun: git -C ~/.config/nvim pull (or :CpPull)", commit_text)
                  vim.notify(msg, vim.log.levels.INFO, { title = "Config Update Available" })
                end)
              elseif force then
                vim.schedule(function()
                  vim.notify("✅ Configuration is up to date with remote.", vim.log.levels.INFO, { title = "Config Update" })
                end)
              end
            end
          )
        end
      )
    end
  )
end

-- Helper command to pull latest configuration updates.
function M.pull_and_verify()
  local config_dir = vim.fn.stdpath("config")
  vim.notify("Pulling latest configuration updates...", vim.log.levels.INFO, { title = "Git Pull" })

  vim.system(
    { "git", "-C", config_dir, "pull" },
    { text = true, timeout = 20000 },
    function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          local out = vim.trim(obj.stdout or "")
          if out:find("Already up to date") then
            vim.notify("✅ Configuration already up to date.", vim.log.levels.INFO, { title = "Git Pull" })
          else
            vim.notify("✅ Configuration updated successfully!", vim.log.levels.INFO, { title = "Git Pull" })
          end
        else
          local err = vim.trim(obj.stderr or obj.stdout or "git pull failed")
          vim.notify("❌ Git pull error: " .. err, vim.log.levels.ERROR, { title = "Git Pull Failed" })
        end
      end)
    end
  )
end

function M.setup()
  vim.api.nvim_create_user_command("CpCheckUpdate", function()
    M.check_for_updates(true)
  end, { desc = "Check for upstream updates in ~/.config/nvim" })

  vim.api.nvim_create_user_command("CpPull", function()
    M.pull_and_verify()
  end, { desc = "Pull latest configuration updates and verify CP health" })
end

return M
