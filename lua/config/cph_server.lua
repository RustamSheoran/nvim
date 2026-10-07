local M = {}
local uv = vim.uv or vim.loop
local server = nil
local current_payload = nil

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
          local response = "HTTP/1.1 200 OK\r\n" ..
                           "Content-Type: application/json\r\n" ..
                           "Access-Control-Allow-Origin: *\r\n" ..
                           "Access-Control-Allow-Headers: *\r\n" ..
                           "Content-Length: " .. tostring(#resp_body) .. "\r\n\r\n" ..
                           resp_body
          client:write(response, function()
            if not client:is_closing() then client:close() end
          end)
          if current_payload then
            current_payload = nil
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
                local judge = task.judge or "Codeforces"
                local contest = (task.group or "Misc"):gsub("[^%w_-]", "_")
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

function M.submit(url, filepath)
  vim.notify("Step 1/2: Checking syntax...", vim.log.levels.INFO, { title = "Submit" })

  -- 1. Fast Syntax Check
  vim.system({ "g++", "-std=c++23", "-fsyntax-only", filepath }, { text = true }, function(syn_obj)
    if syn_obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("=== SYNTAX CHECK FAILED: SUBMISSION ABORTED ===\n" .. syn_obj.stderr, vim.log.levels.ERROR, { title = "Submit" })
      end)
      return
    end

    -- 2. AddressSanitizer & UndefinedBehaviorSanitizer Sanity Check
    vim.schedule(function()
      vim.notify("Step 2/2: Running Sanitizer check (ASan/UBSan)...", vim.log.levels.INFO, { title = "Submit" })
    end)

    local asan_bin = "/tmp/__cph_asan_check"
    vim.system({ "g++", "-O2", "-std=c++23", "-fsanitize=address,undefined", "-g", filepath, "-o", asan_bin }, { text = true }, function(asan_comp)
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
          vim.notify("✅ Sanity check passed! Submitting code to cph-submit...", vim.log.levels.INFO, { title = "Submit" })

          local f = io.open(filepath, "r")
          if not f then
            return
          end
          local source_code = f:read("*a")
          f:close()

          local payload_tbl = {
            empty = false,
            url = url,
            problemName = "",
            languageId = "91", -- C++23 (GCC 14-64, msys2)
            sourceCode = source_code,
          }

          current_payload = vim.fn.json_encode(payload_tbl)
          M.start()
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
