local M = {}
local uv = vim.uv or vim.loop
local server = nil
local servers = {}
local current_payload = nil
local current_payload_platform = nil
local PORTS = { 27121, 10043 }
local recent_tasks = {}
local DEDUPE_WINDOW_MS = 2500

local function is_duplicate_task(task)
  if not task then return false end
  local id = string.format("%s|%s|%s", task.url or "", task.name or "", task.group or "")
  if id == "||" then return false end

  local now = uv.now()
  for k, ts in pairs(recent_tasks) do
    if now - ts > 10000 then
      recent_tasks[k] = nil
    end
  end

  local last_ts = recent_tasks[id]
  if last_ts and (now - last_ts) < DEDUPE_WINDOW_MS then
    return true
  end

  recent_tasks[id] = now
  return false
end

function M.detect_judge_and_contest(task)
  local url = task.url or ""
  local group = task.group or "Misc"
  local judge = "Codeforces"

  if task.judge and task.judge ~= "" then
    judge = task.judge
  elseif url:find("atcoder%.jp") then
    judge = "AtCoder"
  elseif url:find("codechef%.com") then
    judge = "CodeChef"
  elseif url:find("cses%.fi") then
    judge = "CSES"
  elseif url:find("leetcode%.com") then
    judge = "LeetCode"
  elseif url:find("spoj%.com") then
    judge = "SPOJ"
  elseif url:find("kattis%.com") then
    judge = "Kattis"
  elseif url:find("hackerrank%.com") then
    judge = "HackerRank"
  elseif url:find("maang%.in") or url:find("algozenith") then
    judge = "AlgoZenith"
  elseif url:find("codeforces%.com") then
    judge = "Codeforces"
  else
    local prefix = group:match("^([%w_]+)%s*%-")
    if prefix and prefix ~= "" then
      judge = prefix
    end
  end

  local contest = group
  if contest:find("^" .. judge .. "%s*%-") then
    contest = contest:gsub("^" .. judge .. "%s*%-%s*", "")
  end
  contest = contest:gsub("[^%w_-]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  if contest == "" then
    contest = "Misc"
  end

  return judge, contest
end

function M.get_problem_target_path(task, file_extension)
  file_extension = file_extension or "cpp"
  local url = task.url or ""
  local group = task.group or ""
  local name = task.name or "problem"

  local is_mhc = url:find("facebook%.com/codingcompetitions") ~= nil
    or url:find("hacker%-cup") ~= nil
    or url:find("metahackercup") ~= nil
    or group:lower():find("hacker%s*cup") ~= nil
    or group:lower():find("metahackercup") ~= nil

  if is_mhc then
    local year = url:match("hacker%-cup/(20%d%d)")
      or group:match("(20%d%d)")
      or os.date("%Y")

    local round = url:match("hacker%-cup/%d+/([^/]+)")
      or group:match("Round%s*([%w_]+)")
      or group:match("Practice%s*Round")
      or "round"
    round = round:lower():gsub("[^%w]", "")

    local letter = url:match("problems?/([%w_]+)")
      or name:match("^([A-Z]%d?)%s*[:%-]")
      or name:match("^([A-Z]%d?)%s+")
      or name:match("^([A-Z]%d?)$")
      or name:gsub("%s+", "_"):gsub("[^%w_-]", "")

    local prob_name = letter:match("^[A-Z]%d?$") and ("problem" .. letter) or letter
    return string.format("%s/cp/MetaHackerCup/%s/%s/%s/%s.%s",
      vim.fn.expand("~"), year, round, prob_name, prob_name, file_extension)
  end

  local judge, contest = M.detect_judge_and_contest(task)
  local clean_name = name:gsub("%s+", "_"):gsub("[^%w_-]", "")
  return string.format("%s/cp/%s/%s/%s.%s", vim.fn.expand("~"), judge, contest, clean_name, file_extension)
end

function M.get_platform_language_id(platform, lang)
  lang = lang or "cpp"
  local mapping = {
    Codeforces = {
      cpp = 91, -- GNU G++23 14.2 (64 bit, msys2)
      c = 43, -- GNU GCC C11 5.1.0
      python = 70, -- Python 3.8.10
      pypy = 71, -- PyPy 3.7
      rust = 75, -- Rust 1.75.0
      java = 87, -- Java 21
    },
    AtCoder = {
      cpp = 5001, -- C++ 23 (gcc 12.2) [4003 for legacy contests]
      c = 5004, -- C (gcc 12.2)
      python = 5017, -- Python (PyPy 3.10)
      rust = 5018, -- Rust (rustc 1.70.0)
      java = 5021, -- Java (OpenJDK 17)
    },
    CodeChef = {
      cpp = "CPP17",
      c = "C",
      python = "PYTH 3",
      pypy = "PYPY3",
      rust = "RUST",
      java = "JAVA",
    },
    CSES = {
      cpp = "C++",
      c = "C",
      python = "Python3",
      rust = "Rust",
      java = "Java",
    },
    LeetCode = {
      cpp = "cpp",
      c = "c",
      python = "python3",
      rust = "rust",
      java = "java",
    },
    SPOJ = {
      cpp = "44", -- C++14 (gcc 8.3)
      c = "11", -- C (gcc 8.3)
      python = "116", -- Python 3
      rust = "93", -- Rust
      java = "10", -- Java
    },
    Kattis = {
      cpp = "C++",
      c = "C",
      python = "Python 3",
      rust = "Rust",
      java = "Java",
    },
    AlgoZenith = {
      cpp = "54", -- C++14
      c = "48",
      python = "71",
      java = "62",
    },
  }

  local p = mapping[platform]
  if p then
    return p[lang] or p.cpp
  end
  return "91"
end

function M.receive_task(task)
  if not task then return end

  local ok, target_path
  -- Try using competitest user path evaluation if available
  if package.loaded["competitest"] then
    local cfg = require("competitest.config")
    local fn = cfg.received_problems_path or (cfg.current_setup and cfg.current_setup.received_problems_path)
    if type(fn) == "function" then
      ok, target_path = pcall(fn, task, "cpp")
    end
  end

  if not ok or not target_path then
    local judge, contest = M.detect_judge_and_contest(task)
    local name = (task.name or "problem"):gsub("%s+", "_"):gsub("[^%w_-]", "")
    target_path = string.format("%s/cp/%s/%s/%s.cpp", vim.fn.expand("~"), judge, contest, name)
  end

  local dir = vim.fn.fnamemodify(target_path, ":h")
  pcall(vim.fn.mkdir, dir, "p")

  -- Save metadata to companion .meta.json (unified storage for URL, testcases, and limits)
  local meta_file = vim.fn.fnamemodify(target_path, ":r") .. ".meta.json"
  local judge, contest = M.detect_judge_and_contest(task)
  local meta_data = {
    name = task.name or "problem",
    group = task.group or contest,
    url = task.url or "",
    judge = judge,
    timeLimit = task.timeLimit,
    memoryLimit = task.memoryLimit,
    tests = task.tests or {},
  }
  pcall(vim.fn.writefile, { vim.json.encode(meta_data) }, meta_file, "b")

  -- Save source file if not exists
  local is_new_file = vim.fn.filereadable(target_path) == 0
  if is_new_file then
    local template_path = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp")
    if vim.fn.filereadable(template_path) == 1 then
      local template = vim.fn.readfile(template_path)
      pcall(vim.fn.writefile, template, target_path)
    else
      pcall(vim.fn.writefile, {}, target_path)
    end
  end

  -- Pre-mark buffer so LazyVim last_loc does not reset cursor to line 1
  local target_buf = vim.fn.bufadd(target_path)
  vim.b[target_buf].lazyvim_last_loc = true

  -- Find a normal window to edit in (avoiding floats or sidebars)
  local normal_win = nil
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  if vim.bo[cur_buf].buftype == "" and vim.api.nvim_win_get_config(cur_win).relative == "" then
    normal_win = cur_win
  else
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
        normal_win = win
        break
      end
    end
  end
  if not normal_win then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].filetype ~= "neo-tree" and vim.api.nvim_win_get_config(win).relative == "" then
        normal_win = win
        break
      end
    end
  end
  if normal_win and vim.api.nvim_win_is_valid(normal_win) then
    pcall(vim.api.nvim_set_current_win, normal_win)
  end

  local ok_edit = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(target_path))
  if not ok_edit then
    pcall(vim.api.nvim_set_current_buf, target_buf)
  end

  local active_buf = vim.api.nvim_get_current_buf()
  vim.b[active_buf].lazyvim_last_loc = true

  local ok_ac, autocmds = pcall(require, "config.autocmds")
  if ok_ac and autocmds and type(autocmds.position_at_solve) == "function" then
    autocmds.position_at_solve(target_buf, 0, is_new_file)
  end

  vim.notify("Received problem: " .. (task.name or "problem"), vim.log.levels.INFO, { title = "CP Receiver", timeout = 1000 })
  return target_path
end

local function handle_client(client)
  local request_data = ""
  local request_processed = false

  client:read_start(function(read_err, chunk)
    if read_err then
      if not client:is_closing() then client:close() end
      return
    end

    if chunk then
      request_data = request_data .. chunk
    end

    if not request_processed and request_data:find("\r\n\r\n") then
      local content_length = request_data:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")
      local header_end = request_data:find("\r\n\r\n") + 3
      local body = request_data:sub(header_end + 1)

      if content_length and #body < tonumber(content_length) then
        return -- wait for more data
      end

      request_processed = true
      local method, path = request_data:match("^(%u+)%s+(%S+)%s+HTTP/")

      if method == "OPTIONS" then
        local response = "HTTP/1.1 200 OK\r\n" ..
                         "Access-Control-Allow-Origin: *\r\n" ..
                         "Access-Control-Allow-Headers: *\r\n" ..
                         "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" ..
                         "Content-Length: 0\r\n\r\n"
        client:write(response, function()
          if not client:is_closing() then client:close() end
        end)

      elseif method == "GET" and (path == "/getSubmit" or path:match("^/getSubmit%?")) then
        local resp_body = current_payload or '{"empty": true}'
        local is_cph_ext = request_data:lower():find("cph%-submit:%s*true") ~= nil
        local is_cph_supported = (current_payload_platform == "Codeforces" or current_payload_platform == "CSES" or current_payload_platform == "AlgoZenith")
        if is_cph_ext and current_payload_platform and not is_cph_supported then
          resp_body = '{"empty": true}'
        end

        local response = "HTTP/1.1 200 OK\r\n" ..
                         "Content-Type: application/json\r\n" ..
                         "Access-Control-Allow-Origin: *\r\n" ..
                         "Access-Control-Allow-Headers: *\r\n" ..
                         "Content-Length: " .. tostring(#resp_body) .. "\r\n\r\n" ..
                         resp_body
        client:write(response, function()
          if not client:is_closing() then client:close() end
        end)
        if current_payload and resp_body ~= '{"empty": true}' then
          current_payload = nil
          current_payload_platform = nil
        end

      elseif method == "POST" then
        local success, task = pcall(vim.json.decode, body)
        if success and task then
          if not is_duplicate_task(task) then
            vim.schedule(function()
              M.receive_task(task)
            end)
          end
        end

        local response = "HTTP/1.1 200 OK\r\n" ..
                         "Access-Control-Allow-Origin: *\r\n" ..
                         "Content-Length: 0\r\n\r\n"
        client:write(response, function()
          if not client:is_closing() then client:close() end
        end)

      else
        local response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        client:write(response, function()
          if not client:is_closing() then client:close() end
        end)
      end
    end

    if not chunk and not request_processed then
      if not client:is_closing() then client:close() end
    end
  end)
end

local function get_fuser_ports_str()
  local fuser_ports = {}
  for _, port in ipairs(PORTS) do
    table.insert(fuser_ports, tostring(port) .. "/tcp")
  end
  return table.concat(fuser_ports, " ")
end

local function reclaim_stale_ports(on_complete, force_all)
  local my_pid = (vim.uv.os_getpid and vim.uv.os_getpid()) or vim.fn.getpid()
  local parent_pid = (vim.uv.os_getppid and vim.uv.os_getppid()) or 0
  local force_flag = force_all and "1" or "0"
  local fuser_ports = get_fuser_ports_str()

  local script = string.format([[
    for p in $(fuser %s 2>/dev/null); do
      if [ "$p" != "$1" ] && [ "$p" != "$2" ]; then
        if [ "$3" = "1" ] || [ "$(cat /proc/$p/comm 2>/dev/null)" = "nvim" ]; then
          kill -9 "$p" 2>/dev/null
        fi
      fi
    done
  ]], fuser_ports)

  vim.system({ "sh", "-c", script, "--", tostring(my_pid), tostring(parent_pid), force_flag }, {}, function()
    if on_complete then
      vim.schedule(on_complete)
    end
  end)
end

local function try_bind_ports()
  for _, port in ipairs(PORTS) do
    local s = uv.new_tcp()
    local bound, bind_err = s:bind("127.0.0.1", port)
    if bound or not bind_err then
      local listen_success, listen_err = s:listen(128, function(err)
        if err then return end
        local client = uv.new_tcp()
        s:accept(client)
        handle_client(client)
      end)
      if listen_success and not listen_err then
        table.insert(servers, { server = s, port = port })
      else
        s:close()
      end
    else
      s:close()
    end
  end

  if #servers > 0 then
    server = servers[1].server
    return true
  end
  return false
end

function M.start(on_ready)
  if #servers > 0 then
    if on_ready then on_ready(true, servers) end
    return true
  end
  -- Do not start HTTP server in headless sessions (e.g. background daemons)
  if #vim.api.nvim_list_uis() == 0 then
    if on_ready then on_ready(false, {}) end
    return false
  end

  if try_bind_ports() then
    if on_ready then on_ready(true, servers) end
    return true
  end

  -- If initial bind failed, reclaim stale ports asynchronously without blocking UI
  reclaim_stale_ports(function()
    vim.defer_fn(function()
      local ok = try_bind_ports()
      if on_ready then on_ready(ok, servers) end
    end, 50)
  end, false)

  return false
end

function M.restart(on_ready)
  for _, item in ipairs(servers) do
    pcall(function() item.server:close() end)
  end
  servers = {}
  server = nil

  -- Fully non-blocking async port reclamation and bind
  reclaim_stale_ports(function()
    vim.defer_fn(function()
      local ok = try_bind_ports()
      if on_ready then on_ready(ok, servers) end
    end, 50)
  end, false)
end

function M.claim(on_ready)
  for _, item in ipairs(servers) do
    pcall(function() item.server:close() end)
  end
  servers = {}
  server = nil

  -- Forcefully reclaim ports from any other process and bind to this session
  reclaim_stale_ports(function()
    vim.defer_fn(function()
      local ok = try_bind_ports()
      local active_ports = {}
      for _, item in ipairs(servers) do
        table.insert(active_ports, tostring(item.port))
      end

      if on_ready then
        on_ready(ok, servers)
      else
        if ok and #active_ports > 0 then
          vim.notify("🎯 CP ports claimed (" .. table.concat(active_ports, ", ") .. ") for this Neovim session!", vim.log.levels.INFO, { title = "CP Claim", timeout = 1000 })
        else
          vim.notify("❌ Failed to claim CP ports (" .. table.concat(PORTS, ", ") .. ").", vim.log.levels.ERROR, { title = "CP Claim", timeout = 4000 })
        end
      end
    end, 60)
  end, true)
end

local function notify_server_status(servers_list)
  servers_list = servers_list or servers
  local active_ports = {}
  for _, item in ipairs(servers_list) do
    table.insert(active_ports, tostring(item.port))
  end
  if #active_ports > 0 then
    vim.notify("✅ CPH server listening on port(s): " .. table.concat(active_ports, ", "), vim.log.levels.INFO, { title = "CPH Server", timeout = 1000 })
  else
    vim.notify("❌ CPH server failed to bind to ports (" .. table.concat(PORTS, ", ") .. "). Ports are in use.", vim.log.levels.ERROR, { title = "CPH Server", timeout = 4000 })
  end
end

local cp_subcommands = {
  claim = function()
    M.claim()
  end,
  restart = function()
    M.restart(function(_, current_servers)
      notify_server_status(current_servers)
    end)
  end,
  status = function()
    notify_server_status(servers)
  end,
}

local function cp_cmd_handler(opts)
  local arg = vim.trim(opts.args or ""):lower()
  if arg == "claim" then
    cp_subcommands.claim()
  elseif arg == "restart" then
    cp_subcommands.restart()
  elseif arg == "status" or arg == "" then
    cp_subcommands.status()
  else
    vim.notify("Unknown CP subcommand: " .. arg .. "\nUsage: :Cp claim | restart | status", vim.log.levels.WARN, { title = "CP" })
  end
end

local function cp_complete(_, line)
  local parts = vim.split(line, "%s+")
  local candidates = { "claim", "restart", "status" }
  if #parts <= 2 then
    local prefix = (parts[2] or ""):lower()
    return vim.tbl_filter(function(item)
      return item:sub(1, #prefix) == prefix
    end, candidates)
  end
  return {}
end

for _, cmd in ipairs({ "Cp", "CP" }) do
  pcall(vim.api.nvim_create_user_command, cmd, cp_cmd_handler, {
    nargs = "?",
    complete = cp_complete,
    desc = "Competitive Programming server management (:Cp claim | restart | status)",
  })
end

for _, cmd in ipairs({ "CpClaim", "CPClaim" }) do
  pcall(vim.api.nvim_create_user_command, cmd, function()
    M.claim()
  end, { desc = "Claim CP ports for this Neovim session" })
end

for _, cmd_name in ipairs({ "CpRestartServer", "CPRestartServer", "CpRestart", "CPRestart" }) do
  pcall(vim.api.nvim_create_user_command, cmd_name, function()
    M.restart(function(_, current_servers)
      notify_server_status(current_servers)
    end)
  end, { desc = "Restart local CPH HTTP server (non-blocking)" })
end

function M.comment_dbg(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  local modified = false
  local count = 0

  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local new_lines = {}
    for _, line in ipairs(lines) do
      local indent, rest = line:match("^(%s*)(.-)$")
      if rest and not rest:match("^//") and not rest:match("^#") and rest:match("%f[%a_]dbg%s*%(") then
        table.insert(new_lines, indent .. "// " .. rest)
        count = count + 1
        modified = true
      else
        table.insert(new_lines, line)
      end
    end
    if modified then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
      vim.cmd("silent! write")
    end
  else
    local f = io.open(filepath, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local new_lines = {}
      for line in content:gmatch("([^\r\n]*)\r?\n?") do
        local indent, rest = line:match("^(%s*)(.-)$")
        if rest and not rest:match("^//") and not rest:match("^#") and rest:match("%f[%a_]dbg%s*%(") then
          table.insert(new_lines, indent .. "// " .. rest)
          count = count + 1
          modified = true
        else
          table.insert(new_lines, line)
        end
      end
      if modified then
        local out = io.open(filepath, "w")
        if out then
          out:write(table.concat(new_lines, "\n") .. "\n")
          out:close()
        end
      end
    end
  end
  return count
end

function M.uncomment_dbg(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  local modified = false
  local count = 0

  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local new_lines = {}
    for _, line in ipairs(lines) do
      local indent, rest = line:match("^(%s*)(.-)$")
      if rest then
        local uncommented = rest:match("^//%s*(%f[%a_]dbg%s*%b().*)$")
        if uncommented then
          table.insert(new_lines, indent .. uncommented)
          count = count + 1
          modified = true
        else
          table.insert(new_lines, line)
        end
      else
        table.insert(new_lines, line)
      end
    end
    if modified then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
      vim.cmd("silent! write")
    end
  else
    local f = io.open(filepath, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local new_lines = {}
      for line in content:gmatch("([^\r\n]*)\r?\n?") do
        local indent, rest = line:match("^(%s*)(.-)$")
        if rest then
          local uncommented = rest:match("^//%s*(%f[%a_]dbg%s*%b().*)$")
          if uncommented then
            table.insert(new_lines, indent .. uncommented)
            count = count + 1
            modified = true
          else
            table.insert(new_lines, line)
          end
        else
          table.insert(new_lines, line)
        end
      end
      if modified then
        local out = io.open(filepath, "w")
        if out then
          out:write(table.concat(new_lines, "\n") .. "\n")
          out:close()
        end
      end
    end
  end
  return count
end

local asan_ns = vim.api.nvim_create_namespace("cph_asan_error")

function M.clear_asan_errors(bufnr)
  if bufnr and bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, asan_ns, 0, -1)
    pcall(vim.diagnostic.reset, asan_ns, bufnr)
  end
end

pcall(vim.api.nvim_set_hl, 0, "CphAsanErrorLine", { bg = "#5a151b", bold = true, default = true })

function M.highlight_asan_errors(filepath, err_output, testcase_idx)
  local norm_path = vim.fs.normalize(filepath)
  local bufnr = vim.fn.bufnr(norm_path)
  if bufnr == -1 then bufnr = vim.fn.bufnr(filepath) end
  if bufnr == -1 then
    local target_tail = vim.fs.basename(norm_path)
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local bname = vim.api.nvim_buf_get_name(b)
      if bname ~= "" and (vim.fs.normalize(bname) == norm_path or vim.fs.basename(bname) == target_tail) then
        bufnr = b
        break
      end
    end
  end
  if bufnr == -1 then
    bufnr = vim.fn.bufadd(norm_path)
  end
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  M.clear_asan_errors(bufnr)

  local filename = vim.fs.basename(norm_path)
  local errors = {}
  local seen_lines = {}

  -- 1. Check UBSan runtime errors: "path/file.cpp:5:9: runtime error: ..."
  for file, line, col, msg in err_output:gmatch("([^\r\n:]+):(%d+):?(%d*):?%s*runtime error:%s*([^\r\n]+)") do
    if file:find(filename, 1, true) then
      local lnum = tonumber(line)
      if lnum and not seen_lines[lnum] then
        seen_lines[lnum] = true
        table.insert(errors, { line = lnum, col = tonumber(col) or 1, message = "UBSan: " .. msg })
      end
    end
  end

  -- 2. Check ASan summary: "SUMMARY: AddressSanitizer: heap-buffer-overflow /path/file.cpp:6 in solve()"
  for err_type, file, line in err_output:gmatch("SUMMARY:%s*AddressSanitizer:%s*([%w%-_]+)%s+([^\r\n:]+):(%d+)") do
    if file:find(filename, 1, true) then
      local lnum = tonumber(line)
      if lnum and not seen_lines[lnum] then
        seen_lines[lnum] = true
        table.insert(errors, { line = lnum, col = 1, message = "ASan: " .. err_type })
      end
    end
  end

  -- 3. Check stack frames: "#0 0x... in solve() /path/file.cpp:6"
  local top_reason = err_output:match("ERROR:%s*AddressSanitizer:%s*([%w%-_]+)") or "Sanitizer Error"
  for func, file, line in err_output:gmatch("in%s+(.-)%s+([^\r\n%s:]+):(%d+)") do
    if file:find(filename, 1, true) then
      local lnum = tonumber(line)
      if lnum and not seen_lines[lnum] then
        seen_lines[lnum] = true
        table.insert(errors, { line = lnum, col = 1, message = string.format("ASan: %s (in %s)", top_reason, func) })
      end
    end
  end

  -- 4. Fallback: check any pattern "filename:line" in err_output
  if #errors == 0 then
    for line in err_output:gmatch(vim.pesc(filename) .. ":(%d+)") do
      local lnum = tonumber(line)
      if lnum and not seen_lines[lnum] then
        seen_lines[lnum] = true
        table.insert(errors, { line = lnum, col = 1, message = "Sanitizer: " .. top_reason })
      end
    end
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local diags = {}

  for _, err in ipairs(errors) do
    if err.line >= 1 and err.line <= line_count then
      -- Vibrant red line background highlight + Gutter sign + Virtual text at EOL
      pcall(vim.api.nvim_buf_set_extmark, bufnr, asan_ns, err.line - 1, 0, {
        line_hl_group = "CphAsanErrorLine",
        sign_text = "🚨",
        sign_hl_group = "DiagnosticError",
        virt_text = { { string.format("  // 🚨 %s (Sample #%s)", err.message, tostring(testcase_idx or 1)), "DiagnosticError" } },
        virt_text_pos = "eol",
        priority = 10000,
      })

      table.insert(diags, {
        lnum = err.line - 1,
        col = (err.col or 1) - 1,
        severity = vim.diagnostic.severity.ERROR,
        source = "Sanitizer",
        message = string.format("Sample #%d: %s", testcase_idx or 1, err.message),
      })
    end
  end

  if #diags > 0 then
    pcall(vim.diagnostic.set, asan_ns, bufnr, diags)

    -- Focus the buffer window and jump directly to the offending line
    local target_win = nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        target_win = win
        break
      end
    end

    if target_win then
      pcall(vim.api.nvim_set_current_win, target_win)
      pcall(vim.api.nvim_win_set_cursor, target_win, { errors[1].line, (errors[1].col or 1) - 1 })
      pcall(vim.cmd, "normal! zz")
    else
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
          pcall(vim.api.nvim_win_set_buf, win, bufnr)
          pcall(vim.api.nvim_set_current_win, win)
          pcall(vim.api.nvim_win_set_cursor, win, { errors[1].line, (errors[1].col or 1) - 1 })
          pcall(vim.cmd, "normal! zz")
          break
        end
      end
    end
  end

  -- Auto-clear red marks as soon as the user starts editing
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter" }, {
    buffer = bufnr,
    once = true,
    callback = function()
      M.clear_asan_errors(bufnr)
    end,
  })
end

function M.submit(url, filepath)
  local bufnr = vim.fn.bufnr(filepath)
  M.clear_asan_errors(bufnr)

  -- Comment all dbg statements
  local dbg_count = M.comment_dbg(filepath)
  if dbg_count > 0 then
    vim.notify(string.format("Commented out %d dbg statement(s)", dbg_count), vim.log.levels.INFO, { title = "Submit", timeout = 1000 })
  end

  -- 1. Fast Syntax Check
  vim.system({ "g++", "-std=c++17", "-fsyntax-only", filepath }, { text = true }, function(syn_obj)
    if syn_obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("=== SYNTAX CHECK FAILED: SUBMISSION ABORTED ===\n" .. syn_obj.stderr, vim.log.levels.ERROR, { title = "Submit", timeout = 5000 })
      end)
      return
    end

    -- 2. AddressSanitizer & UndefinedBehaviorSanitizer Sanity Check
    local asan_bin = "/tmp/__cph_asan_check"
    local asan_cmd = { "g++", "-O2", "-std=c++17" }
    if vim.fn.executable("mold") == 1 and (vim.uv or vim.loop).os_uname().sysname == "Linux" then
      table.insert(asan_cmd, "-fuse-ld=mold")
    end
    table.insert(asan_cmd, "-fsanitize=address,undefined")
    table.insert(asan_cmd, "-fno-omit-frame-pointer")
    table.insert(asan_cmd, "-g")
    table.insert(asan_cmd, filepath)
    table.insert(asan_cmd, "-o")
    table.insert(asan_cmd, asan_bin)

    vim.system(asan_cmd, { text = true }, function(asan_comp)
      if asan_comp.code ~= 0 then
        vim.schedule(function()
          vim.notify("=== SANITIZER COMPILE FAILED: SUBMISSION ABORTED ===\n" .. asan_comp.stderr, vim.log.levels.ERROR, { title = "Submit", timeout = 5000 })
        end)
        return
      end

      -- Check if sample testcases exist (read from unified .meta.json or legacy .testcases)
      local stem = vim.fn.fnamemodify(filepath, ":r")
      local meta_file = stem .. ".meta.json"
      local tc_file = stem .. ".testcases"
      local tc_list = {}
      if vim.fn.filereadable(meta_file) == 1 then
        pcall(function()
          local lines = vim.fn.readfile(meta_file)
          local ok_dec, data = pcall(vim.json.decode, table.concat(lines, "\n"))
          if ok_dec and type(data) == "table" and data.tests then
            for _, t in ipairs(data.tests) do
              if t.input and t.input ~= "" then
                table.insert(tc_list, t.input)
              end
            end
          end
        end)
      elseif vim.fn.filereadable(tc_file) == 1 then
        pcall(function()
          local tctbl = require("competitest.testcases").single_file.load(tc_file)
          local keys = {}
          for k in pairs(tctbl) do
            table.insert(keys, k)
          end
          table.sort(keys)
          for _, k in ipairs(keys) do
            if tctbl[k] and tctbl[k].input and tctbl[k].input ~= "" then
              table.insert(tc_list, tctbl[k].input)
            end
          end
        end)
      end

      -- Helper to complete submission
      local function do_submit()
        vim.schedule(function()
          pcall(vim.fn.delete, asan_bin)

          local f = io.open(filepath, "r")
          if not f then
            return
          end
          local source_code = f:read("*a")
          f:close()

          -- Always copy verified, sanitized code to system clipboard
          pcall(vim.fn.setreg, "+", source_code)
          pcall(vim.fn.setreg, '"', source_code)

          local platform = "Codeforces"
          if url:find("atcoder%.jp") then
            platform = "AtCoder"
          elseif url:find("codechef%.com") then
            platform = "CodeChef"
          elseif url:find("cses%.fi") then
            platform = "CSES"
          elseif url:find("leetcode%.com") then
            platform = "LeetCode"
          elseif url:find("spoj%.com") then
            platform = "SPOJ"
          elseif url:find("kattis%.com") then
            platform = "Kattis"
          elseif url:find("maang%.in") or url:find("algozenith") then
            platform = "AlgoZenith"
          end

          local function fallback_browser_submit()
            local payload_tbl = {
              empty = false,
              url = url,
              problemName = vim.fn.fnamemodify(filepath, ":t:r"),
              platform = platform,
              languageId = tonumber(M.get_platform_language_id(platform)) or M.get_platform_language_id(platform),
              sourceCode = source_code,
            }

            current_payload = vim.fn.json_encode(payload_tbl)
            current_payload_platform = platform
            M.start()

            if platform == "Codeforces" or platform == "CSES" or platform == "AlgoZenith" then
              vim.notify(string.format("🚀 Submitting %s solution via cph-submit...", platform), vim.log.levels.INFO, { title = "Submit", timeout = 1000 })
              -- Safety fallback: if cph-submit browser extension does not claim payload within 4s, open in browser
              local sub_url = url
              vim.defer_fn(function()
                if current_payload and current_payload_platform == platform then
                  vim.notify("Opening submission page in browser...", vim.log.levels.INFO, { title = "Submit", timeout = 1000 })
                  if vim.ui and vim.ui.open then
                    vim.ui.open(sub_url)
                  else
                    vim.system({ "xdg-open", sub_url }, { detach = true })
                  end
                end
              end, 4000)
            else
              -- AtCoder, CodeChef, LeetCode, and other platforms not supported by cph-submit:
              vim.notify(string.format("✅ %s: Solution copied to clipboard. Opening submission page...", platform), vim.log.levels.INFO, { title = "Submit", timeout = 1000 })
              if vim.ui and vim.ui.open then
                vim.ui.open(url)
              else
                vim.system({ "xdg-open", url }, { detach = true })
              end
            end
          end

          -- If Codeforces: first attempt headless cookie submission if enabled
          if platform == "Codeforces" then
            local cf_cookie = require("config.cf_cookie_submit")
            if cf_cookie.is_cookie_allowed() then
              vim.notify("Submitting solution to Codeforces...", vim.log.levels.INFO, { title = "Codeforces Submit", timeout = 1000 })
              cf_cookie.submit(url, filepath, function(ok, result_or_err)
                if ok then
                  local p_idx = type(result_or_err) == "table" and result_or_err.problem_index
                  local p_str = p_idx and (" " .. p_idx) or ""
                  vim.notify(string.format("✅ Codeforces: Problem%s submitted successfully!", p_str), vim.log.levels.INFO, { title = "Codeforces Submit", timeout = 1000 })
                else
                  if result_or_err == "not_logged_in" then
                    -- User was notified and login page was opened in default browser
                    return
                  end
                  local bname = (package.loaded["config.cf_cookie_submit"] and package.loaded["config.cf_cookie_submit"].last_detected_browser) or "default browser"
                  if result_or_err == "chromium_keyring_locked" then
                    vim.notify(string.format("ℹ️ Submitting in %s via cph-submit...", bname), vim.log.levels.INFO, { title = "Codeforces Submit", timeout = 1000 })
                  else
                    local reason = type(result_or_err) == "string" and result_or_err or "Submission failed"
                    vim.notify(string.format("⚠️ Headless cookie submit unavailable (%s). Submitting in %s...", reason, bname), vim.log.levels.WARN, { title = "Codeforces Submit", timeout = 1000 })
                  end
                  fallback_browser_submit()
                end
              end)
              return
            else
              -- Cookie submit is disabled globally by user (<leader>rk)
              fallback_browser_submit()
              return
            end
          end

          -- Non-Codeforces platforms:
          fallback_browser_submit()
        end)
      end

      if #tc_list == 0 then
        do_submit()
        return
      end

      -- Run against each sample testcase
      local function run_testcase(index)
        if index > #tc_list then
          do_submit()
          return
        end

        vim.system({ asan_bin }, {
          stdin = tc_list[index],
          text = true,
          env = {
            ASAN_OPTIONS = "handle_abort=1:detect_leaks=1",
            UBSAN_OPTIONS = "print_stacktrace=1:halt_on_error=1",
          },
        }, function(run_obj)
          local err_output = (run_obj.stderr or "") .. (run_obj.stdout or "")
          local has_asan_err = run_obj.code ~= 0
            or err_output:find("AddressSanitizer")
            or err_output:find("runtime error:")

          if has_asan_err then
            vim.schedule(function()
              pcall(vim.fn.delete, asan_bin)
              M.highlight_asan_errors(filepath, err_output, index)
              local msg = string.format("🚨 SANITIZER ERROR ON SAMPLE TESTCASE #%d: SUBMISSION ABORTED!\n\n%s", index, err_output)
              vim.notify(msg, vim.log.levels.ERROR, { title = "Submit Aborted", timeout = 5000 })
            end)
            return
          end

          run_testcase(index + 1)
        end)
      end

      run_testcase(1)
    end)
  end)
end

return M
