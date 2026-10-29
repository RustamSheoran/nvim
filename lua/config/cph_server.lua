local M = {}
local uv = vim.uv or vim.loop
local server = nil
local current_payload = nil
local current_payload_platform = nil

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
  if server then return end
  server = uv.new_tcp()
  
  local bound, bind_err = server:bind("127.0.0.1", 27121)
  if not bound and bind_err then
    server:close()
    server = nil
    return
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
              if vim.fn.filereadable(target_path) == 0 then
                local template_path = vim.fn.expand("~/.config/nvim/templates/cp_template.cpp")
                if vim.fn.filereadable(template_path) == 1 then
                  local template = vim.fn.readfile(template_path)
                  vim.fn.writefile(template, target_path)
                else
                  vim.fn.writefile({}, target_path)
                end
              end
              
              vim.cmd("edit " .. target_path)
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
  end
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

function M.highlight_asan_errors(filepath, err_output, testcase_idx)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  M.clear_asan_errors(bufnr)

  local filename = vim.fn.fnamemodify(filepath, ":t")
  local errors = {}
  local seen_lines = {}

  -- 1. Check UBSan runtime errors: "path/file.cpp:5:9: runtime error: ..."
  for file, line, col, msg in err_output:gmatch("([^\r\n:]+):(%d+):(%d+):%s*runtime error:%s*([^\r\n]+)") do
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
  for func, file, line in err_output:gmatch("in%s+([%w_]+)%s*%b()%s+([^\r\n:]+):(%d+)") do
    if file:find(filename, 1, true) then
      local lnum = tonumber(line)
      if lnum and not seen_lines[lnum] then
        seen_lines[lnum] = true
        table.insert(errors, { line = lnum, col = 1, message = string.format("ASan: %s (in %s)", top_reason, func) })
      end
    end
  end

  if #errors == 0 then
    -- Fallback: check any pattern "filename:line" in err_output
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
      -- Red line background highlight + Red virtual comment at end of line
      pcall(vim.api.nvim_buf_set_extmark, bufnr, asan_ns, err.line - 1, 0, {
        line_hl_group = "DiffDelete",
        virt_text = { { "  // 🚨 " .. err.message, "DiagnosticError" } },
        virt_text_pos = "eol",
        priority = 5000,
      })

      table.insert(diags, {
        lnum = err.line - 1,
        col = (err.col or 1) - 1,
        severity = vim.diagnostic.severity.ERROR,
        source = "Sanitizer",
        message = string.format("Sample #%d: %s", testcase_idx, err.message),
      })
    end
  end

  if #diags > 0 then
    pcall(vim.diagnostic.set, asan_ns, bufnr, diags)
    -- Jump window cursor directly to the first offending line
    pcall(vim.api.nvim_win_set_cursor, 0, { errors[1].line, (errors[1].col or 1) - 1 })
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

  -- Step 1/3: Comment all dbg statements
  local dbg_count = M.comment_dbg(filepath)
  if dbg_count > 0 then
    vim.notify(string.format("Step 1/3: Commented out %d dbg statement(s)...", dbg_count), vim.log.levels.INFO, { title = "Submit" })
  else
    vim.notify("Step 1/3: No active dbg statements found...", vim.log.levels.INFO, { title = "Submit" })
  end

  vim.notify("Step 2/3: Checking syntax...", vim.log.levels.INFO, { title = "Submit" })

  -- 1. Fast Syntax Check
  vim.system({ "g++", "-std=c++17", "-fsyntax-only", filepath }, { text = true }, function(syn_obj)
    if syn_obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("=== SYNTAX CHECK FAILED: SUBMISSION ABORTED ===\n" .. syn_obj.stderr, vim.log.levels.ERROR, { title = "Submit" })
      end)
      return
    end

    -- 2. AddressSanitizer & UndefinedBehaviorSanitizer Sanity Check
    vim.schedule(function()
      vim.notify("Step 3/3: Running Sanitizer check (ASan/UBSan)...", vim.log.levels.INFO, { title = "Submit" })
    end)

    local asan_bin = "/tmp/__cph_asan_check"
    vim.system({ "g++", "-O2", "-std=c++17", "-fuse-ld=mold", "-fsanitize=address,undefined", "-g", filepath, "-o", asan_bin }, { text = true }, function(asan_comp)
      if asan_comp.code ~= 0 then
        vim.schedule(function()
          vim.notify("=== SANITIZER COMPILE FAILED: SUBMISSION ABORTED ===\n" .. asan_comp.stderr, vim.log.levels.ERROR, { title = "Submit" })
        end)
        return
      end

      -- Check if sample testcases exist
      local tc_file = vim.fn.fnamemodify(filepath, ":r") .. ".testcases"
      local tc_list = {}
      if vim.fn.filereadable(tc_file) == 1 then
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
          vim.notify("✅ Sanity check passed! Submitting code...", vim.log.levels.INFO, { title = "Submit" })

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
              problemName = "",
              platform = platform,
              languageId = M.get_platform_language_id(platform),
              sourceCode = source_code,
            }

            current_payload = vim.fn.json_encode(payload_tbl)
            current_payload_platform = platform
            M.start()

            if platform == "Codeforces" or platform == "CSES" or platform == "AlgoZenith" then
              if platform == "Codeforces" then
                vim.notify("Opening Codeforces submission in browser via cph-submit...", vim.log.levels.INFO, { title = "Submit" })
                if vim.ui and vim.ui.open then
                  vim.ui.open(url)
                else
                  vim.system({ "xdg-open", url }, { detach = true })
                end
                vim.defer_fn(function()
                  pcall(function()
                    require("config.codeforces").watch_submission(nil, nil, nil)
                  end)
                end, 800)
              end
            else
              -- AtCoder, CodeChef, LeetCode, and other platforms:
              vim.notify(string.format("✅ %s: Opening submission page in browser...", platform), vim.log.levels.INFO, { title = "Submit" })
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
              vim.notify("🚀 Submitting directly via browser cookies (zero browser overhead)...", vim.log.levels.INFO, { title = "Codeforces Submit" })
              cf_cookie.submit(url, filepath, function(ok, result_or_err)
                if ok then
                  local handle = type(result_or_err) == "table" and result_or_err.handle
                  local c_id = type(result_or_err) == "table" and result_or_err.contest_id
                  local p_idx = type(result_or_err) == "table" and result_or_err.problem_index
                  vim.notify(string.format("✅ Codeforces submission sent for %s (%s)! Watching verdict...", p_idx or "problem", handle or "user"), vim.log.levels.INFO, { title = "Codeforces Submit" })
                  pcall(function()
                    require("config.codeforces").watch_submission(handle, c_id, p_idx)
                  end)
                else
                  if result_or_err == "not_logged_in" then
                    -- User was notified and login page was opened in browser
                    return
                  end
                  local reason = type(result_or_err) == "string" and result_or_err or "Submission failed"
                  vim.notify(string.format("⚠️ Headless cookie submit failed (%s). Falling back to browser cph-submit...", reason), vim.log.levels.WARN, { title = "Codeforces Submit" })
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

        vim.system({ asan_bin }, { stdin = tc_list[index], text = true }, function(run_obj)
          local err_output = (run_obj.stderr or "") .. (run_obj.stdout or "")
          local has_asan_err = run_obj.code ~= 0
            or err_output:find("AddressSanitizer")
            or err_output:find("runtime error:")

          if has_asan_err then
            vim.schedule(function()
              pcall(vim.fn.delete, asan_bin)
              M.highlight_asan_errors(filepath, err_output, index)
              local msg = string.format("🚨 SANITIZER ERROR ON SAMPLE TESTCASE #%d: SUBMISSION ABORTED!\n\n%s", index, err_output)
              vim.notify(msg, vim.log.levels.ERROR, { title = "Submit Aborted" })
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
