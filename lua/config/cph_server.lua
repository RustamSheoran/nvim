local M = {}
local uv = vim.uv or vim.loop
local server = nil
local current_payload = nil
local current_payload_platform = nil
local max_request_bytes = 16 * 1024 * 1024

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
      cpp = "91", -- GNU G++23 14.2 (64 bit, msys2)
      c = "43", -- GNU GCC C11 5.1.0
      python = "70", -- Python 3.8.10
      pypy = "71", -- PyPy 3.7
      rust = "75", -- Rust 1.75.0
      java = "87", -- Java 21
    },
    AtCoder = {
      cpp = "5001", -- C++ 23 (gcc 12.2) [4003 for legacy contests]
      c = "5004", -- C (gcc 12.2)
      python = "5017", -- Python (PyPy 3.10)
      rust = "5018", -- Rust (rustc 1.70.0)
      java = "5021", -- Java (OpenJDK 17)
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

function M.start()
  if server then return true end
  server = uv.new_tcp()
  
  local bound, bind_err = server:bind("127.0.0.1", 27121)
  if not bound and bind_err then
    vim.schedule(function()
      vim.notify("CPH server could not bind 127.0.0.1:27121: " .. tostring(bind_err), vim.log.levels.ERROR, { title = "CPH Server" })
    end)
    server:close()
    server = nil
    return false
  end
  
  local listen_success, listen_err = server:listen(128, function(err)
    if err then return end
    local client = uv.new_tcp()
    server:accept(client)
    
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

      if #request_data > max_request_bytes then
        if not client:is_closing() then
          client:write("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n", function()
            if not client:is_closing() then client:close() end
          end)
        end
        return
      end
      
      if not request_processed and request_data:find("\r\n\r\n") then
        local content_length = request_data:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")
        if content_length and tonumber(content_length) > max_request_bytes then
          client:write("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n", function()
            if not client:is_closing() then client:close() end
          end)
          request_processed = true
          return
        end
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
          -- Filter: if cph-submit extension is requesting but current_payload is NOT for Codeforces/CSES/AlgoZenith:
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
          -- Parse competitive companion JSON and simulate node extension
          local success, task = pcall(vim.json.decode, body)
          if success and task then
            vim.schedule(function()
              local ok, target_path
              -- Try using competitest user path evaluation if available
              if package.loaded["competitest"] then
                local cfg = require("competitest.config")
                if type(cfg.received_problems_path) == "function" then
                  ok, target_path = pcall(cfg.received_problems_path, task, "cpp")
                end
              end
              
              if not ok or not target_path then
                local judge, contest = M.detect_judge_and_contest(task)
                local name = (task.name or "problem"):gsub("%s+", "_"):gsub("[^%w_-]", "")
                target_path = string.format("%s/cp/%s/%s/%s.cpp", vim.fn.expand("~"), judge, contest, name)
              end
              
              local dir = vim.fn.fnamemodify(target_path, ":h")
              vim.fn.mkdir(dir, "p")
              
              -- Save URL for cph-submit
              if task.url and task.url ~= "" then
                local url_file = vim.fn.fnamemodify(target_path, ":r") .. ".url"
                vim.fn.writefile({ task.url }, url_file, "b")
                vim.fn.writefile({ vim.json.encode({ url = task.url, judge = task.judge, group = task.group, name = task.name }) }, vim.fn.fnamemodify(target_path, ":r") .. ".meta.json", "b")
              end
              
              -- Save testcases via competitest msgpack file natively
              local tctbl = {}
              if task.tests then
                for i, test in ipairs(task.tests) do
                  tctbl[i-1] = { input = test.input, output = test.output }
                end
              end
              local testcases_file = vim.fn.fnamemodify(target_path, ":r") .. ".testcases"
              local mpack_success, mpack = pcall(vim.mpack.encode, tctbl)
              if mpack_success then
                local f = io.open(testcases_file, "wb")
                if f then
                  f:write(mpack)
                  f:close()
                end
              end
              
              -- Save source file if not exists
              local is_new_file = vim.fn.filereadable(target_path) == 0
              if is_new_file then
                local template_path = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp")
                if vim.fn.filereadable(template_path) == 1 then
                  local template = vim.fn.readfile(template_path)
                  vim.fn.writefile(template, target_path)
                else
                  vim.fn.writefile({}, target_path)
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
              if normal_win and vim.api.nvim_win_is_valid(normal_win) then
                pcall(vim.api.nvim_set_current_win, normal_win)
              end

              vim.cmd("edit " .. vim.fn.fnameescape(target_path))

              local ok_ac, autocmds = pcall(require, "config.autocmds")
              if ok_ac and autocmds and type(autocmds.position_at_solve) == "function" then
                autocmds.position_at_solve(target_buf, 0, is_new_file)
              end

              vim.notify("Received problem: " .. (task.name or "problem"), vim.log.levels.INFO)
            end)
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
  end)
  
  if listen_err then
    server:close()
    server = nil
    return false
  end
  return listen_success ~= false
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

function M.toggle_dbg(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  local lines
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    local f = io.open(filepath, "r")
    if not f then return 0 end
    lines = vim.split(f:read("*a"), "\n", { plain = true })
    f:close()
  end
  for _, line in ipairs(lines) do
    local rest = line:match("^%s*(.-)$")
    if rest and not rest:match("^//") and not rest:match("^#") and rest:match("%f[%a_]dbg%s*%(") then
      return M.comment_dbg(filepath)
    end
  end
  return M.uncomment_dbg(filepath)
end


-- Direct submission path: no syntax check, sanitizer build, testcase execution,
-- source rewriting, or verdict polling. The editor submits exactly what is saved.
M.submit = function(url, filepath)
  local f = io.open(filepath, "r")
  if not f then
    vim.notify("Cannot read solution: " .. filepath, vim.log.levels.ERROR, { title = "Submit" })
    return
  end
  local source_code = f:read("*a")
  f:close()
  pcall(vim.fn.setreg, "+", source_code)
  pcall(vim.fn.setreg, '"', source_code)

  local platform = "Other"
  if url:find("codeforces%.com") then
    platform = "Codeforces"
  elseif url:find("atcoder%.jp") then
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
  local payload = vim.fn.json_encode({
    empty = false,
    url = url,
    problemName = "",
    platform = platform,
    languageId = platform == "Codeforces" and M.get_platform_language_id(platform, "cpp") or "91",
    sourceCode = source_code,
  })
  current_payload = payload
  current_payload_platform = platform
  if not M.start() then
    current_payload = nil
    current_payload_platform = nil
    vim.notify("Cannot submit: local CPH server is unavailable on port 27121.", vim.log.levels.ERROR, { title = "Submit" })
    return
  end
  vim.notify("Submission payload ready; opening submission page.", vim.log.levels.INFO, { title = "Submit" })
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
  else
    vim.system({ "xdg-open", url }, { detach = true })
  end
end

return M
