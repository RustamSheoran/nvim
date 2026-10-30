local M = {}

local handle_file = vim.fn.stdpath("config") .. "/codeforces_handle.txt"

-- Title case helper (e.g. "candidate master" -> "Candidate Master")
local function title_case(str)
  if not str or str == "" then
    return ""
  end
  return (str:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest:lower()
  end))
end

-- Codeforces Rank Tiers
local rank_tiers = {
  { threshold = 1200, name = "Pupil", short = "Pupil", hl = "CfDiffGreen" },
  { threshold = 1400, name = "Specialist", short = "Specialist", hl = "CfDiffCyan" },
  { threshold = 1600, name = "Expert", short = "Expert", hl = "CfDiffBlue" },
  { threshold = 1900, name = "Candidate Master", short = "CM", hl = "CfDiffPurple" },
  { threshold = 2100, name = "Master", short = "Master", hl = "CfDiffOrange" },
  { threshold = 2300, name = "International Master", short = "IM", hl = "CfDiffOrange" },
  { threshold = 2400, name = "Grandmaster", short = "GM", hl = "CfDiffRed" },
  { threshold = 2600, name = "International Grandmaster", short = "IGM", hl = "CfDiffRed" },
  { threshold = 3000, name = "Legendary Grandmaster", short = "LGM", hl = "CfDiffRed" },
}

local function get_next_rankup(rating)
  for _, tier in ipairs(rank_tiers) do
    if tier.threshold > rating then
      return tier, tier.threshold - rating
    end
  end
  return nil, nil
end

-- Format contest start date (YYYY-MM-DD) and relative age (e.g. "2y 5m 12d old contest")
local function format_contest_date_and_age(start_ts)
  if not start_ts or type(start_ts) ~= "number" or start_ts <= 0 then
    return nil, nil
  end
  local ok, date_str = pcall(os.date, "%Y-%m-%d", start_ts)
  if not ok or not date_str then
    return nil, nil
  end

  local now_ts = os.time()
  if now_ts < start_ts then
    return date_str, "upcoming"
  end

  local t1 = os.date("*t", start_ts)
  local t2 = os.date("*t", now_ts)

  local years = t2.year - t1.year
  local months = t2.month - t1.month
  local days = t2.day - t1.day

  if days < 0 then
    local prev_month = t2.month - 1
    local prev_year = t2.year
    if prev_month == 0 then
      prev_month = 12
      prev_year = prev_year - 1
    end
    local days_in_prev = os.date("*t", os.time({ year = prev_year, month = prev_month + 1, day = 0 })).day
    days = days + days_in_prev
    months = months - 1
  end

  if months < 0 then
    months = months + 12
    years = years - 1
  end

  local parts = {}
  if years > 0 then table.insert(parts, years .. "y") end
  if months > 0 then table.insert(parts, months .. "m") end
  if days > 0 then table.insert(parts, days .. "d") end

  if #parts == 0 then
    return date_str, "today"
  end

  return date_str, table.concat(parts, " ") .. " old contest"
end

-- Elo win probability formula used by Codeforces / Carrot / Repovive
local function elo_prob(ra, rb)
  return 1.0 / (1.0 + 10.0 ^ ((rb - ra) / 400.0))
end

-- Fast expected seed calculation from rating histogram
local function get_seed_from_hist(target_rating, hist, self_rating)
  local seed = 1.0
  for r, count in pairs(hist) do
    seed = seed + count * elo_prob(r, target_rating)
  end
  if self_rating then
    seed = seed - elo_prob(self_rating, target_rating)
  end
  return seed
end

-- Binary search performance rating from expected rank
local function rank_to_rating(rank, self_rating, hist)
  local left = -500
  local right = 6000
  while right - left > 1 do
    local mid = math.floor((left + right) / 2)
    if get_seed_from_hist(mid, hist, self_rating) < rank then
      right = mid
    else
      left = mid
    end
  end
  return left
end

-- Carrot rating delta formula
local function calc_delta_from_hist(rank, rating, hist)
  local seed = get_seed_from_hist(rating, hist, rating)
  local mid_rank = math.sqrt(rank * seed)
  local need_rating = rank_to_rating(mid_rank, rating, hist)
  return math.floor((need_rating - rating) / 2) - 2
end

-- For live contests: approximate division rating distribution
local function generate_div_hist(contest_name, n)
  local lower = (contest_name or ""):lower()
  local mean = 1450
  local std = 200

  if lower:find("div%.%s*1%s*%+%s*div%.%s*2") or lower:find("global") or (lower:find("round") and not lower:find("div%.")) then
    mean = 1600
    std = 350
  elseif lower:find("div%.%s*1") then
    mean = 2100
    std = 220
  elseif lower:find("div%.%s*2") then
    mean = 1450
    std = 200
  elseif lower:find("div%.%s*3") then
    mean = 1200
    std = 180
  elseif lower:find("div%.%s*4") then
    mean = 1000
    std = 180
  end

  local hist = {}
  local step = 25
  for r = 400, 3600, step do
    local z = (r - mean) / std
    local prob = math.exp(-0.5 * z * z) / (std * math.sqrt(2 * math.pi))
    local count = math.floor(prob * step * n + 0.5)
    if count > 0 then
      hist[r] = count
    end
  end
  return hist
end

-- Problem difficulty rating estimation via binary search over contestant ratings (from repovive)
-- Note: only run when contest phase is FINISHED (never during CODING or SYSTEM_TEST)
local function estimate_problem_rating(solvers_count, total_contestants, hist)
  if solvers_count == 0 then return 3500 end
  if solvers_count >= total_contestants then return 800 end

  local function expected_solvers(prob_r)
    local sum = 0
    for r, count in pairs(hist) do
      sum = sum + count * elo_prob(r, prob_r)
    end
    return sum
  end

  local low = 400
  local high = 4000
  for _ = 1, 50 do
    local mid = (low + high) / 2
    if expected_solvers(mid) > solvers_count then
      low = mid
    else
      high = mid
    end
  end
  return math.floor((high + 50) / 100) * 100
end

-- Get CF color tier highlight group for problem rating
local function get_diff_hl(rating)
  if not rating or rating < 1200 then
    return "CfDiffGray"
  elseif rating < 1400 then
    return "CfDiffGreen"
  elseif rating < 1600 then
    return "CfDiffCyan"
  elseif rating < 1900 then
    return "CfDiffBlue"
  elseif rating < 2100 then
    return "CfDiffPurple"
  elseif rating < 2400 then
    return "CfDiffOrange"
  else
    return "CfDiffRed"
  end
end

-- Get or prompt for Codeforces handle
function M.get_handle(callback)
  if vim.g.codeforces_handle and vim.g.codeforces_handle ~= "" then
    if callback then callback(vim.g.codeforces_handle) end
    return vim.g.codeforces_handle
  end

  if vim.fn.filereadable(handle_file) == 1 then
    local lines = vim.fn.readfile(handle_file)
    if #lines > 0 and vim.trim(lines[1]) ~= "" then
      vim.g.codeforces_handle = vim.trim(lines[1])
      if callback then callback(vim.g.codeforces_handle) end
      return vim.g.codeforces_handle
    end
  end

  if callback then
    vim.ui.input({ prompt = "Enter your Codeforces Handle: " }, function(input)
      if input and vim.trim(input) ~= "" then
        local h = vim.trim(input)
        vim.g.codeforces_handle = h
        pcall(vim.fn.writefile, { h }, handle_file)
        callback(h)
      else
        callback(nil)
      end
    end)
  end

  return nil
end

-- Detect contest ID from file path or companion .url file
function M.detect_contest_id(filepath)
  filepath = filepath or vim.api.nvim_buf_get_name(0)

  -- 1. Check companion .url file
  local url_file = vim.fn.fnamemodify(filepath, ":r") .. ".url"
  if vim.fn.filereadable(url_file) == 1 then
    local lines = vim.fn.readfile(url_file)
    if #lines > 0 then
      local u = lines[1]
      local c_id = u:match("contest/(%d+)") or u:match("problemset/problem/(%d+)") or u:match("gym/(%d+)")
      if c_id then return c_id end
    end
  end

  -- 2. Check path pattern e.g. /cp/Codeforces/1119/ or contest/1119/
  local c_id = filepath:match("Codeforces[/\\](%d+)") or filepath:match("contest[/\\](%d+)")
  if c_id then return c_id end

  return nil
end

-- ==============================================================================
-- 1. Live Submission Verdict Watcher (Notifications for passed testcases)
-- ==============================================================================
-- Desktop OS Notification Helper (Accepted & Final Verdicts Only)
-- ==============================================================================
local function send_desktop_notification(title, message, urgency)
  urgency = urgency or "normal"
  local is_mac = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1
  if is_mac then
    local script = string.format('display notification %q with title %q', message, title)
    pcall(vim.system, { "osascript", "-e", script }, { detach = true })
  else
    if vim.fn.executable("notify-send") == 1 then
      pcall(vim.system, { "notify-send", "-u", urgency, "-a", "Codeforces", title, message }, { detach = true })
    end
  end
end

-- ==============================================================================
local active_watchers = {}

function M.watch_submission(handle, contest_id, problem_index)
  if not handle then
    M.get_handle(function(h)
      if h then
        M.watch_submission(h, contest_id, problem_index)
      end
    end)
    return
  end

  contest_id = contest_id or M.detect_contest_id()

  local watcher_key = handle .. "_" .. (contest_id or "all")
  if active_watchers[watcher_key] then
    -- Already watching
    return
  end
  active_watchers[watcher_key] = true

  vim.notify(string.format("👀 Watching Codeforces submissions for handle: %s...", handle), vim.log.levels.INFO, { title = "Codeforces Watch" })

  local last_passed = -1
  local attempts = 0
  local max_attempts = 200 -- ~3.5 minutes timeout
  local poll_interval_ms = 700 -- Fast 700ms sleep after response (combined with ~350-400ms curl = ~1.05s-1.1s total on-the-wire cycle)
  local min_request_gap_ms = 1000 -- Hard floor: strictly enforce >= 1000ms between requests on the wire
  local last_req_time = 0
  local watch_start_ts = os.time()
  local watch_start_ms = vim.uv.now()
  local ua = (vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1)
      and "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:134.0) Gecko/20100101 Firefox/134.0"
    or "Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0"

  local function poll()
    if not active_watchers[watcher_key] then
      return
    end

    local now = vim.uv.now()
    local elapsed = now - last_req_time
    if elapsed < min_request_gap_ms then
      vim.defer_fn(poll, min_request_gap_ms - elapsed)
      return
    end

    attempts = attempts + 1
    if attempts > max_attempts then
      active_watchers[watcher_key] = nil
      vim.notify("⏱️ Watch timeout: submission is taking longer than usual.", vim.log.levels.WARN, { title = "Codeforces Watch" })
      return
    end

    last_req_time = vim.uv.now()
    local req_send_time = vim.uv.now()
    local api_url = string.format("https://codeforces.com/api/user.status?handle=%s&from=1&count=5", handle)
    vim.system({ "curl", "-s", "-A", ua, api_url }, { text = true }, function(obj)
      local req_elapsed_ms = vim.uv.now() - req_send_time
      local resp_sec_str = string.format("%.1fs", req_elapsed_ms / 1000)
      local total_sec_str = string.format("%.1fs", (vim.uv.now() - watch_start_ms) / 1000)

      if not active_watchers[watcher_key] then
        return
      end

      if obj.code ~= 0 or not obj.stdout or obj.stdout == "" then
        vim.defer_fn(poll, poll_interval_ms)
        return
      end

      vim.schedule(function()
        if not active_watchers[watcher_key] then
          return
        end

        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok or not data or data.status ~= "OK" or not data.result or #data.result == 0 then
          -- If Codeforces throttles with "Call limit exceeded", back off 3.5s to replenish token bucket
          local is_rate_limited = (data and data.comment and data.comment:lower():find("limit exceeded"))
            or (obj.stdout and obj.stdout:lower():find("limit exceeded"))
          local delay = is_rate_limited and 3500 or poll_interval_ms
          vim.defer_fn(poll, delay)
          return
        end

        local sub = data.result[1]

        -- If top submission was created before this watch started, new submission is still in flight
        if sub.creationTimeSeconds and sub.creationTimeSeconds < (watch_start_ts - 5) then
          vim.defer_fn(poll, poll_interval_ms)
          return
        end

        local p_idx = (sub.problem and sub.problem.index) or ""
        local p_name = (sub.problem and sub.problem.name) or "Problem"
        local passed = sub.passedTestCount or 0
        local verdict = sub.verdict
        local time_ms = sub.timeConsumedMillis or 0
        local mem_kb = math.floor((sub.memoryConsumedBytes or 0) / 1024)

        if verdict == nil or verdict == "TESTING" or verdict == "SUBMITTED" then
          if passed > last_passed then
            last_passed = passed
            -- Intermediate testcase updates stay in Neovim notify ONLY (no OS notification spam)
            if passed > 0 then
              vim.notify(string.format("⏳ [%s] Testcase %d passed... (Running on test %d) [took %s to get response]", p_idx, passed, passed + 1, resp_sec_str), vim.log.levels.INFO, { title = "Codeforces Watch" })
            else
              vim.notify(string.format("⏳ [%s] Running on test 1... [took %s to get response]", p_idx, resp_sec_str), vim.log.levels.INFO, { title = "Codeforces Watch" })
            end
          end
          vim.defer_fn(poll, poll_interval_ms)
        else
          -- Finished judging! Trigger desktop OS notification for final verdict only
          active_watchers[watcher_key] = nil

          if verdict == "OK" then
            local msg = string.format("🎉 [%s] %s: ACCEPTED!\nPassed %d testcases (took %s, response in %s)\nTime: %d ms | Memory: %d KB", p_idx, p_name, passed, total_sec_str, resp_sec_str, time_ms, mem_kb)
            vim.notify(msg, vim.log.levels.INFO, { title = "Codeforces Verdict" })
            send_desktop_notification("Codeforces: ACCEPTED! 🎉", string.format("[%s] %s: Passed %d testcases in %s (%d ms)", p_idx, p_name, passed, total_sec_str, time_ms), "normal")
          elseif verdict == "WRONG_ANSWER" then
            local msg = string.format("❌ [%s] %s: WRONG ANSWER on test %d (took %s, response in %s)\nTime: %d ms | Memory: %d KB", p_idx, p_name, passed + 1, total_sec_str, resp_sec_str, time_ms, mem_kb)
            vim.notify(msg, vim.log.levels.ERROR, { title = "Codeforces Verdict" })
            send_desktop_notification("Codeforces: WRONG ANSWER ❌", string.format("[%s] %s on test %d in %s (%d ms)", p_idx, p_name, passed + 1, total_sec_str, time_ms), "critical")
          elseif verdict == "TIME_LIMIT_EXCEEDED" then
            local msg = string.format("⌛ [%s] %s: TIME LIMIT EXCEEDED on test %d (took %s, response in %s)\nTime: %d ms", p_idx, p_name, passed + 1, total_sec_str, resp_sec_str, time_ms)
            vim.notify(msg, vim.log.levels.ERROR, { title = "Codeforces Verdict" })
            send_desktop_notification("Codeforces: TIME LIMIT EXCEEDED ⌛", string.format("[%s] %s on test %d in %s (%d ms)", p_idx, p_name, passed + 1, total_sec_str, time_ms), "critical")
          elseif verdict == "MEMORY_LIMIT_EXCEEDED" then
            local msg = string.format("💥 [%s] %s: MEMORY LIMIT EXCEEDED on test %d (took %s, response in %s)\nMemory: %d KB", p_idx, p_name, passed + 1, total_sec_str, resp_sec_str, mem_kb)
            vim.notify(msg, vim.log.levels.ERROR, { title = "Codeforces Verdict" })
            send_desktop_notification("Codeforces: MEMORY LIMIT EXCEEDED 💥", string.format("[%s] %s on test %d in %s (%d KB)", p_idx, p_name, passed + 1, total_sec_str, mem_kb), "critical")
          elseif verdict == "COMPILATION_ERROR" then
            local msg = string.format("⚠️ [%s] %s: COMPILATION ERROR (took %s, response in %s)", p_idx, p_name, total_sec_str, resp_sec_str)
            vim.notify(msg, vim.log.levels.ERROR, { title = "Codeforces Verdict" })
            send_desktop_notification("Codeforces: COMPILATION ERROR ⚠️", string.format("[%s] %s in %s", p_idx, p_name, total_sec_str), "critical")
          else
            local msg = string.format("🚨 [%s] %s: %s on test %d (took %s, response in %s)\nTime: %d ms | Memory: %d KB", p_idx, p_name, verdict, passed + 1, total_sec_str, resp_sec_str, time_ms, mem_kb)
            vim.notify(msg, vim.log.levels.WARN, { title = "Codeforces Verdict" })
            send_desktop_notification("Codeforces: " .. verdict:gsub("_", " "), string.format("[%s] %s on test %d in %s", p_idx, p_name, passed + 1, total_sec_str), "normal")
          end
        end
      end)
    end)
  end

  -- Start first poll after 400ms for near-instant first testcase visibility
  vim.defer_fn(poll, 400)
end

-- ==============================================================================
-- 2. Contest Standings, Live / Carrot Rating Prediction & Problem Difficulty
-- ==============================================================================
function M.show_contest_list(contest_id, force_refresh)
  contest_id = contest_id or M.detect_contest_id()

  if not contest_id then
    vim.ui.input({ prompt = "Enter Codeforces Contest ID: " }, function(input)
      if input and vim.trim(input) ~= "" then
        M.show_contest_list(vim.trim(input), force_refresh)
      end
    end)
    return
  end

  local handle = M.get_handle()
  local cache_dir = vim.fn.stdpath("cache") .. "/codeforces"
  local cache_file = string.format("%s/contest_%s.json", cache_dir, tostring(contest_id))

  local standings_data = nil
  local rating_changes_data = nil
  local user_info_data = nil
  local unofficial_status_data = nil
  local checked_unofficial = false
  local is_from_cache = false

  local function render_popup()
    if not standings_data or standings_data.status ~= "OK" or not standings_data.result then
      local err_msg = (standings_data and standings_data.comment) or "Failed to fetch contest standings"
      vim.notify("Codeforces Error: " .. err_msg, vim.log.levels.ERROR, { title = "Codeforces" })
      return
    end

    local contest = standings_data.result.contest or {}
    local problems = standings_data.result.problems or {}
    local rows = standings_data.result.rows or {}

    -- 1. Parse User Profile Info & Next Rankup Target
    local uinfo = user_info_data and user_info_data.result and user_info_data.result[1]
    local u_rating = uinfo and uinfo.rating or 1400
    local u_rank_title = uinfo and title_case(uinfo.rank or "Unrated") or "Unrated"
    local u_max_rating = uinfo and uinfo.maxRating or u_rating
    local next_tier, pts_needed = get_next_rankup(u_rating)

    -- 2. Build Rating Histogram from official ratingChanges or division approximation
    local hist = {}
    local rc_by_handle = {}
    local total_contestants = #rows > 0 and #rows or 5000

    if rating_changes_data and rating_changes_data.status == "OK" and rating_changes_data.result and #rating_changes_data.result > 0 then
      total_contestants = #rating_changes_data.result
      for _, rc in ipairs(rating_changes_data.result) do
        if rc.handle then
          rc_by_handle[rc.handle:lower()] = rc
        end
        local old = rc.oldRating
        if not old or old <= 0 then old = 1400 end
        hist[old] = (hist[old] or 0) + 1
      end
    else
      hist = generate_div_hist(contest.name or "", total_contestants)
    end

    -- 3. Calculate solve count for each problem & find user row
    local solve_counts = {}
    for i = 1, #problems do
      solve_counts[i] = 0
    end

    local user_row = nil
    for _, row in ipairs(rows) do
      if handle and row.party and row.party.members then
        for _, m in ipairs(row.party.members) do
          if m.handle and m.handle:lower() == handle:lower() then
            user_row = row
            break
          end
        end
      end

      if row.problemResults then
        for i, res in ipairs(row.problemResults) do
          if res.points and res.points > 0 then
            solve_counts[i] = (solve_counts[i] or 0) + 1
          end
        end
      end
    end

    local user_rc = handle and rc_by_handle[handle:lower()]

    -- Check if user is OUT of contest: only fetch unofficial status if user was not in official contest!
    if not user_row and not user_rc and handle and not checked_unofficial then
      checked_unofficial = true
      local status_url = string.format("https://codeforces.com/api/user.status?handle=%s&from=1&count=60", handle)
      vim.system({ "curl", "-s", status_url }, { text = true }, function(u_obj)
        if u_obj.code == 0 and u_obj.stdout and u_obj.stdout ~= "" then
          pcall(function()
            unofficial_status_data = vim.json.decode(u_obj.stdout)
          end)
        end
        vim.schedule(render_popup)
      end)
      return
    end

    -- 4. Parse unofficial solves if user is out of contest
    local unofficial_solves = {}
    local unofficial_cnt = 0
    local unofficial_pts = 0

    if not user_row and unofficial_status_data and unofficial_status_data.result then
      for _, sub in ipairs(unofficial_status_data.result) do
        local p = sub.problem
        if p and tostring(p.contestId) == tostring(contest_id) and sub.verdict == "OK" then
          if not unofficial_solves[p.index] then
            unofficial_solves[p.index] = true
            unofficial_cnt = unofficial_cnt + 1
            local pts = p.points and math.floor(p.points * 0.8) or 1
            unofficial_pts = unofficial_pts + pts
          end
        end
      end
    end

    -- 5. Determine user standing & rating delta
    local cur_pts = user_row and user_row.points or unofficial_pts
    local cur_rank = user_row and user_row.rank or #rows
    local cur_delta = nil
    local base_official = nil
    local base_calc = nil

    if user_rc then
      base_official = user_rc.newRating - user_rc.oldRating
      base_calc = calc_delta_from_hist(user_rc.rank, user_rc.oldRating, hist)
      cur_delta = base_official
      cur_rank = user_rc.rank
    elseif user_row and cur_pts > 0 then
      cur_delta = calc_delta_from_hist(cur_rank, u_rating, hist)
    elseif not user_row and unofficial_cnt > 0 then
      -- Compute virtual rank among official contestants
      local unoff_rank = 1
      for _, r in ipairs(rows) do
        if r.points and r.points > unofficial_pts then
          unoff_rank = unoff_rank + 1
        end
      end
      cur_rank = unoff_rank
      cur_delta = calc_delta_from_hist(cur_rank, u_rating, hist)
    end

    -- 6. Format lines for floating window & track highlight ranges
    local lines = {}
    local highlights = {} -- list of { line = idx, col_start = s, col_end = e, hl = group }

    local c_name = contest.name or ("Contest " .. contest_id)
    local phase = contest.phase or "FINISHED"
    local is_live = (phase == "CODING")
    local is_testing = (phase == "SYSTEM_TEST")
    local is_pending = (phase == "PENDING_SYSTEM_TEST")

    table.insert(lines, string.format(" 🏆 %s", c_name))
    local phase_tag = is_live and " (LIVE CONTEST RUNNING!)"
      or (is_testing and " (SYSTEM TESTS RUNNING / RE-RUNNING!)"
      or (is_pending and " (PENDING SYSTEM TESTS)" or ""))
    table.insert(lines, string.format(" 📡 Phase: %s%s", phase, phase_tag))

    local date_str, age_str = format_contest_date_and_age(contest.startTimeSeconds)
    if date_str and age_str then
      local date_line = string.format(" 📅 Date: %s (%s)", date_str, age_str)
      table.insert(lines, date_line)
      table.insert(highlights, { line = #lines - 1, col_start = 1, col_end = #date_line, hl = "CfDiffGray" })
    end

    if handle then
      local profile_str = string.format(" 👤 Handle: %s | Rating: %d (%s) | Max: %d", handle, u_rating, u_rank_title, u_max_rating)
      table.insert(lines, profile_str)

      if user_row and cur_pts > 0 then
        local solved_cnt = 0
        if user_row.problemResults then
          for _, res in ipairs(user_row.problemResults) do
            if res.points and res.points > 0 then
              solved_cnt = solved_cnt + 1
            end
          end
        end

        local official_rank = (user_rc and user_rc.rank) or (user_row and user_row.rank) or "-"
        local raw_rank = user_row and user_row.rank
        local rank_main = string.format("Rank #%s", tostring(official_rank))
        local rank_faded = ""
        if raw_rank and user_rc and user_rc.rank and raw_rank ~= user_rc.rank then
          rank_faded = string.format(" (#%d)", raw_rank)
        end

        local standing_line = string.format(" 📊 Standing: %s%s | Points: %s | Solved: %d/%d", rank_main, rank_faded, tostring(cur_pts), solved_cnt, #problems)
        table.insert(lines, standing_line)

        local line_num = #lines - 1
        local s_main = standing_line:find(rank_main, 1, true) - 1
        table.insert(highlights, { line = line_num, col_start = s_main, col_end = s_main + #rank_main, hl = "CfBold" })

        if rank_faded ~= "" then
          local s_faded = standing_line:find(rank_faded, 1, true) - 1
          table.insert(highlights, { line = line_num, col_start = s_faded, col_end = s_faded + #rank_faded, hl = "CfDiffGray" })
        end

        if cur_delta then
          local old_r = user_rc and user_rc.oldRating or u_rating
          local new_r = user_rc and user_rc.newRating or (u_rating + cur_delta)
          local sign = cur_delta >= 0 and "+" or ""
          local delta_num_str = string.format("%s%d", sign, cur_delta)

          local needed_str = ""
          if next_tier and pts_needed then
            needed_str = string.format("  (+%d needed to %s)", pts_needed, next_tier.short)
          end

          local delta_line = string.format(" 📈 Rating Delta: %d -> %d  %s%s", old_r, new_r, delta_num_str, needed_str)
          table.insert(lines, delta_line)

          local l_idx = #lines - 1
          local s_col = delta_line:find(delta_num_str, 1, true) - 1
          local e_col = s_col + #delta_num_str
          local hl_grp = cur_delta >= 0 and "CfDeltaPlus" or "CfDeltaMinus"
          table.insert(highlights, { line = l_idx, col_start = s_col, col_end = e_col, hl = hl_grp })

          if needed_str ~= "" and next_tier then
            local s_needed = delta_line:find(needed_str, 1, true) - 1
            table.insert(highlights, { line = l_idx, col_start = s_needed, col_end = s_needed + #needed_str, hl = next_tier.hl })
          end

          -- Guaranteed Rankup Promotion Banner (shown only on this special occasion!)
          if next_tier and new_r >= next_tier.threshold then
            local promo_line = string.format(" ✨ GUARANTEED %s AFTER THIS CONTEST! CONGRATS! ✨", next_tier.name:upper())
            table.insert(lines, promo_line)
            table.insert(highlights, { line = #lines - 1, col_start = 0, col_end = #promo_line, hl = next_tier.hl })
          end
        end
      elseif not user_row and unofficial_cnt > 0 then
        -- User is out of contest but solved problems unofficially / virtual
        table.insert(lines, string.format(" 📊 Standing: Rank #%d (Unofficial / Virtual) | Solved: %d/%d", cur_rank, unofficial_cnt, #problems))

        if cur_delta then
          local new_r = u_rating + cur_delta
          local sign = cur_delta >= 0 and "+" or ""
          local delta_num_str = string.format("%s%d", sign, cur_delta)
          local delta_line = string.format(" 📈 Projected Delta: %d -> %d  %s", u_rating, new_r, delta_num_str)
          table.insert(lines, delta_line)

          local l_idx = #lines - 1
          local s_col = #delta_line - #delta_num_str
          local e_col = #delta_line
          local hl_grp = cur_delta >= 0 and "CfDeltaPlus" or "CfDeltaMinus"
          table.insert(highlights, { line = l_idx, col_start = s_col, col_end = e_col, hl = hl_grp })
        end
      else
        table.insert(lines, " 📊 Standing: Out of contest (No submissions recorded)")
      end
    end

    table.insert(lines, string.rep("─", 80))
    table.insert(lines, string.format(" %-5s %-28s %-7s %-8s %-7s %-12s", "Idx", "Problem Name", "Solved", "Diff", "Pts", "Status"))
    table.insert(lines, string.rep("─", 80))

    local problem_urls = {}
    local unsolved = {}

    for i, prob in ipairs(problems) do
      local p_idx = prob.index or "?"
      local p_title = prob.name or "Problem"
      if #p_title > 26 then
        p_title = p_title:sub(1, 23) .. "..."
      end
      local solves = solve_counts[i] or 0
      local pts = prob.points and tostring(prob.points) or "-"

      -- Problem difficulty rating:
      -- 1. Official rating if Codeforces assigned it
      -- 2. Binary search estimation ONLY if contest phase == "FINISHED"
      -- 3. During CODING or SYSTEM_TEST, diff cannot be accurately computed, so show "-"
      local diff_val = nil
      local diff_str = "-"
      if prob.rating and type(prob.rating) == "number" then
        diff_val = prob.rating
        diff_str = tostring(prob.rating)
      elseif phase ~= "SYSTEM_TEST" and phase ~= "BEFORE" and solves > 0 then
        -- Run binary search difficulty estimation unless system tests are actively rerunning!
        diff_val = estimate_problem_rating(solves, total_contestants, hist)
        diff_str = string.format("~%d*", diff_val)
      else
        -- Disabled during active SYSTEM_TEST (when all submissions are being re-evaluated)
        diff_str = "-"
      end

      local status_str = "-"
      local is_solved = false
      if user_row and user_row.problemResults and user_row.problemResults[i] then
        local r = user_row.problemResults[i]
        if r.points and r.points > 0 then
          is_solved = true
          status_str = "✔ Solved"
          if r.rejectedAttemptCount and r.rejectedAttemptCount > 0 then
            status_str = string.format("✔ (+%d)", r.rejectedAttemptCount)
          end
        elseif r.rejectedAttemptCount and r.rejectedAttemptCount > 0 then
          status_str = string.format("✘ (-%d)", r.rejectedAttemptCount)
        end
      elseif not user_row and unofficial_solves[p_idx] then
        is_solved = true
        status_str = "✔ Solved (Unoff)"
      end

      if not is_solved then
        table.insert(unsolved, { index = i, prob = prob, diff = diff_val })
      end

      local line_text = string.format(" [%s]  %-28s %-7s %-8s %-7s %-12s", p_idx, p_title, string.format("%d", solves), diff_str, pts, status_str)
      table.insert(lines, line_text)
      problem_urls[#lines] = string.format("https://codeforces.com/contest/%s/problem/%s", contest_id, p_idx)

      local cur_line_idx = #lines - 1

      -- Highlight difficulty rating using Codeforces color tiers
      if diff_str ~= "-" and diff_val then
        local diff_s = line_text:find(diff_str, 1, true)
        if diff_s then
          table.insert(highlights, { line = cur_line_idx, col_start = diff_s - 1, col_end = diff_s - 1 + #diff_str, hl = get_diff_hl(diff_val) })
        end
      end

      -- Highlight status
      if status_str:find("✔") then
        local s_col = line_text:find("✔") - 1
        table.insert(highlights, { line = cur_line_idx, col_start = s_col, col_end = s_col + #status_str, hl = "CfDeltaPlus" })
      elseif status_str:find("✘") then
        local s_col = line_text:find("✘") - 1
        table.insert(highlights, { line = cur_line_idx, col_start = s_col, col_end = s_col + #status_str, hl = "CfDeltaMinus" })
      end
    end

    -- 6. What-If Solve Projections (New rank & predicted delta at end)
    if #unsolved > 0 and handle then
      table.insert(lines, string.rep("─", 80))
      table.insert(lines, " 🎯 What-If Solve Projections:")

      for _, item in ipairs(unsolved) do
        local p_idx = item.prob.index
        local p_pts = item.prob.points or 1
        local add_pts = p_pts > 1 and math.floor(p_pts * 0.8) or 1
        local hyp_pts = cur_pts + add_pts

        local hyp_rank = 1
        for _, r in ipairs(rows) do
          if r.points and r.points > hyp_pts then
            hyp_rank = hyp_rank + 1
          end
        end

        local calc_d = calc_delta_from_hist(hyp_rank, u_rating, hist)
        local proj_delta = calc_d
        if base_official and base_calc then
          proj_delta = base_official + (calc_d - base_calc)
        end

        local sign = proj_delta >= 0 and "+" or ""
        local delta_num_str = string.format("%s%d", sign, proj_delta)
        local pts_label = p_pts > 1 and string.format("+%d pts", add_pts) or "+1 solve"
        local diff_tag = item.diff and string.format(" [%d]", item.diff) or ""

        local new_predicted_r = u_rating + proj_delta
        local promo_tag = ""
        if next_tier and new_predicted_r >= next_tier.threshold then
          promo_tag = string.format(" [%s Rankup!]", next_tier.short)
        end

        local w_line = string.format("  • Solve [%s]%s (%s) -> New Rank: #%-4d  %s%s",
          p_idx, diff_tag, pts_label, hyp_rank, delta_num_str, promo_tag)
        table.insert(lines, w_line)

        local cur_line_idx = #lines - 1
        local delta_pos = w_line:find(delta_num_str, 1, true)
        if delta_pos then
          local s_col = delta_pos - 1
          local e_col = s_col + #delta_num_str
          local hl_grp = proj_delta >= 0 and "CfDeltaPlus" or "CfDeltaMinus"
          table.insert(highlights, { line = cur_line_idx, col_start = s_col, col_end = e_col, hl = hl_grp })
        end

        if promo_tag ~= "" and next_tier then
          local promo_pos = w_line:find(promo_tag, 1, true)
          if promo_pos then
            table.insert(highlights, { line = cur_line_idx, col_start = promo_pos - 1, col_end = promo_pos - 1 + #promo_tag, hl = next_tier.hl })
          end
        end
      end

      -- If >= 2 unsolved problems, also show combo for next 2 solves
      if #unsolved >= 2 then
        local p1 = unsolved[1]
        local p2 = unsolved[2]
        local p1_pts = p1.prob.points and math.floor(p1.prob.points * 0.8) or 1
        local p2_pts = p2.prob.points and math.floor(p2.prob.points * 0.8) or 1
        local combo_pts = cur_pts + p1_pts + p2_pts

        local combo_rank = 1
        for _, r in ipairs(rows) do
          if r.points and r.points > combo_pts then
            combo_rank = combo_rank + 1
          end
        end

        local combo_calc = calc_delta_from_hist(combo_rank, u_rating, hist)
        local combo_delta = combo_calc
        if base_official and base_calc then
          combo_delta = base_official + (combo_calc - base_calc)
        end

        local combo_sign = combo_delta >= 0 and "+" or ""
        local combo_num_str = string.format("%s%d", combo_sign, combo_delta)
        local combo_pts_label = (p1.prob.points or p2.prob.points) and string.format("+%d pts", p1_pts + p2_pts) or "+2 solves"
        local combo_new_r = u_rating + combo_delta

        local combo_promo_tag = ""
        if next_tier and combo_new_r >= next_tier.threshold then
          combo_promo_tag = string.format(" [%s Rankup!]", next_tier.short)
        end

        local combo_line = string.format("  • Solve [%s + %s] (%s) -> New Rank: #%-4d  %s%s",
          p1.prob.index, p2.prob.index, combo_pts_label, combo_rank, combo_num_str, combo_promo_tag)
        table.insert(lines, combo_line)

        local cur_line_idx = #lines - 1
        local delta_pos = combo_line:find(combo_num_str, 1, true)
        if delta_pos then
          local s_col = delta_pos - 1
          local e_col = s_col + #combo_num_str
          local hl_grp = combo_delta >= 0 and "CfDeltaPlus" or "CfDeltaMinus"
          table.insert(highlights, { line = cur_line_idx, col_start = s_col, col_end = e_col, hl = hl_grp })
        end

        if combo_promo_tag ~= "" and next_tier then
          local promo_pos = combo_line:find(combo_promo_tag, 1, true)
          if promo_pos then
            table.insert(highlights, { line = cur_line_idx, col_start = promo_pos - 1, col_end = promo_pos - 1 + #combo_promo_tag, hl = next_tier.hl })
          end
        end
      end
    end

    table.insert(lines, string.rep("─", 80))
    table.insert(lines, " [Enter/o] Open in Browser   [s] Set Handle   [r] Refresh   [q/Esc] Close")

    -- 7. Render Floating Window
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].buftype = "nofile"

    -- Define highlight colors for delta and Codeforces difficulty tiers
    vim.api.nvim_set_hl(0, "CfBold",        { bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDeltaPlus",   { fg = "#39d353", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDeltaMinus",  { fg = "#ff5555", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDiffGray",    { fg = "#888888", default = true })
    vim.api.nvim_set_hl(0, "CfDiffGreen",   { fg = "#39d353", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDiffCyan",    { fg = "#00c4b4", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDiffBlue",    { fg = "#4a9eff", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDiffPurple",  { fg = "#c055ff", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDiffOrange",  { fg = "#ffaa00", bold = true, default = true })
    vim.api.nvim_set_hl(0, "CfDiffRed",     { fg = "#ff5555", bold = true, default = true })

    local ns = vim.api.nvim_create_namespace("codeforces_standings_hl")
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_add_highlight, buf, ns, h.hl, h.line, h.col_start, h.col_end)
    end

    local width = 84
    local height = math.min(#lines + 2, vim.o.lines - 4)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local title_text = is_from_cache
      and " Codeforces Contest Standings & Rating Predictor [Cached | 'r' to reload] "
      or " Codeforces Contest Standings & Rating Predictor "

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = title_text,
      title_pos = "center",
    })

    -- Keymaps inside popup
    local function close_win()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end

    vim.keymap.set("n", "q", close_win, { buffer = buf, nowait = true })
    vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, nowait = true })
    vim.keymap.set("n", "r", function()
      close_win()
      M.show_contest_list(contest_id, true)
    end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "s", function()
      close_win()
      vim.ui.input({ prompt = "Enter Codeforces Handle: " }, function(new_h)
        if new_h and vim.trim(new_h) ~= "" then
          vim.g.codeforces_handle = vim.trim(new_h)
          pcall(vim.fn.writefile, { vim.g.codeforces_handle }, handle_file)
          M.show_contest_list(contest_id, false)
        end
      end)
    end, { buffer = buf, nowait = true })

    local function open_current_problem()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local cur_line = cursor[1]
      local target_url = problem_urls[cur_line]
      if target_url then
        close_win()
        if vim.ui and vim.ui.open then
          vim.ui.open(target_url)
        else
          vim.system({ "xdg-open", target_url }, { detach = true })
        end
      end
    end

    vim.keymap.set("n", "<CR>", open_current_problem, { buffer = buf, nowait = true })
    vim.keymap.set("n", "o", open_current_problem, { buffer = buf, nowait = true })

    -- Save to persistent disk cache if contest is finished / not running
    if is_finished then
      pcall(function()
        vim.fn.mkdir(cache_dir, "p")
        local existing = {}
        if vim.fn.filereadable(cache_file) == 1 then
          local ok_r, raw = pcall(vim.fn.readfile, cache_file)
          if ok_r and raw and #raw > 0 then
            local ok_d, parsed = pcall(vim.json.decode, table.concat(raw, "\n"))
            if ok_d and parsed then existing = parsed end
          end
        end

        local user_cache = existing.user_cache or {}
        if handle and (user_info_data or unofficial_status_data) then
          local h_lower = handle:lower()
          user_cache[h_lower] = {
            info = user_info_data or (user_cache[h_lower] and user_cache[h_lower].info),
            unofficial = unofficial_status_data or (user_cache[h_lower] and user_cache[h_lower].unofficial),
          }
        end

        local payload = {
          contest_id = contest_id,
          cached_at = os.time(),
          standings = standings_data,
          rating_changes = (rating_changes_data and rating_changes_data.status == "OK" and rating_changes_data.result and #rating_changes_data.result > 0)
            and rating_changes_data
            or existing.rating_changes,
          user_cache = user_cache,
        }
        vim.fn.writefile({ vim.json.encode(payload) }, cache_file)
      end)
    end
  end

  -- 1. Persistent cache check (near-instant if finished or not running)
  if not force_refresh and vim.fn.filereadable(cache_file) == 1 then
    local ok_read, raw_lines = pcall(vim.fn.readfile, cache_file)
    if ok_read and raw_lines and #raw_lines > 0 then
      local ok_dec, cached = pcall(vim.json.decode, table.concat(raw_lines, "\n"))
      if ok_dec and cached and cached.standings and cached.standings.result then
        local c = cached.standings.result.contest or {}
        local c_phase = c.phase or "FINISHED"
        local c_finished = (c_phase == "FINISHED") or (c_phase ~= "CODING" and c_phase ~= "SYSTEM_TEST" and c_phase ~= "PENDING_SYSTEM_TEST")
        if c_finished then
          standings_data = cached.standings
          rating_changes_data = cached.rating_changes
          is_from_cache = true

          local h_lower = handle and handle:lower() or nil
          if h_lower and cached.user_cache and cached.user_cache[h_lower] then
            user_info_data = cached.user_cache[h_lower].info
            unofficial_status_data = cached.user_cache[h_lower].unofficial
            checked_unofficial = true
            vim.schedule(render_popup)
            return
          elseif not handle then
            vim.schedule(render_popup)
            return
          else
            -- We have cached standings and rating changes; only fetch user info
            local user_url = string.format("https://codeforces.com/api/user.info?handles=%s", handle)
            vim.system({ "curl", "-s", user_url }, { text = true }, function(obj)
              if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
                pcall(function()
                  user_info_data = vim.json.decode(obj.stdout)
                end)
              end
              vim.schedule(render_popup)
            end)
            return
          end
        end
      end
    end
  end

  vim.notify("Fetching contest standings, ratings and difficulty estimates...", vim.log.levels.INFO, { title = "Codeforces" })

  local pending = handle and 3 or 2

  -- Parallel API Fetch 1: contest.standings
  local standings_url = string.format("https://codeforces.com/api/contest.standings?contestId=%s", contest_id)
  vim.system({ "curl", "-s", standings_url }, { text = true }, function(obj)
    if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
      pcall(function()
        standings_data = vim.json.decode(obj.stdout)
      end)
    end
    step_done()
  end)

  -- Parallel API Fetch 2: contest.ratingChanges
  local rc_url = string.format("https://codeforces.com/api/contest.ratingChanges?contestId=%s", contest_id)
  vim.system({ "curl", "-s", rc_url }, { text = true }, function(obj)
    if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
      pcall(function()
        rating_changes_data = vim.json.decode(obj.stdout)
      end)
    end
    step_done()
  end)

  -- Parallel API Fetch 3: user.info (if handle is set)
  if handle then
    local user_url = string.format("https://codeforces.com/api/user.info?handles=%s", handle)
    vim.system({ "curl", "-s", user_url }, { text = true }, function(obj)
      if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
        pcall(function()
          user_info_data = vim.json.decode(obj.stdout)
        end)
      end
      step_done()
    end)
  end
end

-- ==============================================================================
-- 3. Live Contest Countdown Timer HUD (<leader>rT)
-- ==============================================================================
local active_timer_handle = nil

function M.show_contest_timer(contest_id)
  contest_id = contest_id or M.detect_contest_id()
  vim.notify("Fetching Codeforces contest schedule...", vim.log.levels.INFO, { title = "Contest Timer" })

  local ua = (vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1)
      and "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:134.0) Gecko/20100101 Firefox/134.0"
    or "Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0"

  vim.system({ "curl", "-s", "-A", ua, "https://codeforces.com/api/contest.list?gym=false" }, { text = true }, function(obj)
    if obj.code ~= 0 or not obj.stdout or obj.stdout == "" then
      vim.schedule(function()
        vim.notify("Failed to fetch contest schedule from Codeforces", vim.log.levels.ERROR, { title = "Contest Timer" })
      end)
      return
    end

    local ok, data = pcall(vim.json.decode, obj.stdout)
    if not ok or not data or data.status ~= "OK" or not data.result then
      vim.schedule(function()
        vim.notify("Invalid API response from Codeforces", vim.log.levels.ERROR, { title = "Contest Timer" })
      end)
      return
    end

    vim.schedule(function()
      local target_contest = nil

      -- 1. If contest_id is provided, match by ID
      if contest_id then
        local cid_num = tonumber(contest_id)
        for _, c in ipairs(data.result) do
          if c.id == cid_num then
            target_contest = c
            break
          end
        end
      end

      -- 2. Otherwise look for an active CODING contest
      if not target_contest then
        for _, c in ipairs(data.result) do
          if c.phase == "CODING" then
            target_contest = c
            break
          end
        end
      end

      if not target_contest or target_contest.phase ~= "CODING" then
        vim.notify("No live Codeforces contest currently in progress.", vim.log.levels.INFO, { title = "Contest Timer" })
        return
      end

      -- Create floating timer HUD
      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "wipe"

      local width = 64
      local height = 10
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " ⏱️ Live Codeforces Contest Timer ",
        title_pos = "center",
      })

      local base_time = os.time()
      local init_rel_time = target_contest.relativeTimeSeconds or 0
      local duration = target_contest.durationSeconds or 7200

      local function format_duration(sec)
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        local s = sec % 60
        return string.format("%02d:%02d:%02d", h, m, s)
      end

      local function update_hud()
        if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
          if active_timer_handle then
            active_timer_handle:close()
            active_timer_handle = nil
          end
          return
        end

        local elapsed = os.time() - base_time
        local current_rel = init_rel_time + elapsed

        local lines = {}
        table.insert(lines, "")
        local name_line = string.format("  🏆 %s", target_contest.name or "Codeforces Round")
        if #name_line > width - 2 then
          name_line = name_line:sub(1, width - 5) .. "..."
        end
        table.insert(lines, name_line)
        table.insert(lines, string.format("  🆔 Contest ID: %s | Duration: %s", tostring(target_contest.id), format_duration(duration)))
        table.insert(lines, "  " .. string.rep("─", width - 4))

        if current_rel >= 0 and current_rel <= duration then
          local remaining = math.max(0, duration - current_rel)
          local pct = math.min(100, math.floor((current_rel / duration) * 100))
          table.insert(lines, "  🔴 Status: LIVE CONTEST (Coding Phase)")
          table.insert(lines, string.format("  ⏳ Time Remaining:  %s  (%d%% elapsed)", format_duration(remaining), pct))
          local bar_width = 30
          local filled = math.floor((pct / 100) * bar_width)
          local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
          table.insert(lines, string.format("  [%s]", bar))
        else
          table.insert(lines, "  ⚪ Status: FINISHED")
          table.insert(lines, "  Contest has ended. Check standings with <leader>rl")
          table.insert(lines, "")
        end

        table.insert(lines, "  " .. string.rep("─", width - 4))
        table.insert(lines, "  Press [q] or [Esc] to close")

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
      end

      update_hud()

      -- Ticking timer: updates HUD every second while window is open
      if active_timer_handle then
        active_timer_handle:close()
        active_timer_handle = nil
      end

      local timer = vim.uv.new_timer()
      active_timer_handle = timer
      timer:start(1000, 1000, vim.schedule_wrap(update_hud))

      local function close_hud()
        if active_timer_handle then
          active_timer_handle:close()
          active_timer_handle = nil
        end
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end

      vim.keymap.set("n", "q", close_hud, { buffer = buf, nowait = true })
      vim.keymap.set("n", "<Esc>", close_hud, { buffer = buf, nowait = true })

      vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, {
        buffer = buf,
        once = true,
        callback = function()
          if active_timer_handle then
            active_timer_handle:close()
            active_timer_handle = nil
          end
        end,
      })
    end)
  end)
end

return M
