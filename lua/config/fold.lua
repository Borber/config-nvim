-- ============================================
-- 折叠子模块
-- ============================================
-- 1. foldexpr：基于 treesitter folds query，同起点仅保留最外层 fold，
--    避免方法链按内层 call_expression 分裂。
-- 2. foldtext：保留首/末行的 treesitter 语法高亮，并补充前缀、` ⋯ ` 分隔与
--    `[N lines hidden]` 提示。

local M = {}

local FOLD_PREFIX = "◇ "
local FOLD_PREFIX_HL = "ConfigFoldPrefix"
local FOLD_MUTED_HL = "ConfigFoldMuted"
local FOLD_PREVIEW_HL = "ConfigFoldPreview"
local FOLD_TAIL_HL = "ConfigFoldTail"
local FOLD_PREFIX_WIDTH = vim.fn.strdisplaywidth(FOLD_PREFIX)

-- ============================================
-- foldexpr：同起点只保留最外层 fold
-- ============================================
local cache = {}

-- folds query 收集 → 同起点取最长 → 计算覆盖深度 → 输出 marker。
local function build_markers(bufnr)
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return {}
  end
  parser:parse()

  local longest = {}
  parser:for_each_tree(function(tree, ltree)
    local query = vim.treesitter.query.get(ltree:lang(), "folds")
    if not query then
      return
    end
    for _, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
      local sr, _, er, ec = node:range()
      if ec == 0 then
        er = er - 1 -- node:range() 在 ec==0 时表示该行不入范围
      end
      local s, e = sr + 1, er + 1
      if er > sr and (not longest[s] or e > longest[s]) then
        longest[s] = e
      end
    end
  end)

  local depth = {}
  for s, e in pairs(longest) do
    for ln = s, e do
      depth[ln] = (depth[ln] or 0) + 1
    end
  end

  local markers = {}
  for ln = 1, vim.api.nvim_buf_line_count(bufnr) do
    markers[ln] = longest[ln] and (">" .. depth[ln]) or tostring(depth[ln] or 0)
  end
  return markers
end

vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
  group = vim.api.nvim_create_augroup("ConfigFoldCache", { clear = true }),
  callback = function(args)
    cache[args.buf] = nil
  end,
})

function M.foldexpr(lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local entry = cache[bufnr]
  if not entry or entry.tick ~= tick then
    entry = { tick = tick, markers = build_markers(bufnr) }
    cache[bufnr] = entry
  end
  return entry.markers[lnum] or "0"
end

-- ============================================
-- foldtext：保留首/末行 treesitter 语法高亮
-- ============================================
-- 单遍扫描：每字节按 priority 高者覆盖；priority 相等时后到者胜出，
-- 与 nvim TSHighlighter 同优先级 extmark “后画在上”一致。
local function collect_ts_highlights(bufnr, lnum, line_len)
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return {}
  end

  local row = lnum - 1
  parser:parse({ row, row + 1 })

  local per_col, prio_col = {}, {}
  parser:for_each_tree(function(tree, ltree)
    local lang = ltree:lang()
    local query = vim.treesitter.query.get(lang, "highlights")
    if not query then
      return
    end
    for id, node, metadata in query:iter_captures(tree:root(), bufnr, row, row + 1) do
      local sr, sc, er, ec = node:range()
      local s = sr < row and 0 or sc
      local e = er > row and line_len or ec
      if e > s then
        -- `(#set! @cap "priority" N)` 写入 metadata[id]；`(#set! "priority" N)` 写入 metadata。
        local cap_meta = metadata[id]
        local priority = (cap_meta and cap_meta.priority)
          or metadata.priority
          or vim.highlight.priorities.treesitter
        local hl = "@" .. query.captures[id] .. "." .. lang
        for col = s + 1, e do
          if (prio_col[col] or -1) <= priority then
            per_col[col] = hl
            prio_col[col] = priority
          end
        end
      end
    end
  end)

  return per_col
end

-- 将行内 [from, to]（1-indexed，默认整行）切成 {text, hl} 连续段。
local function line_to_parts(line, per_col, fallback, from, to)
  from, to = from or 1, to or #line
  if from > to then
    return {}
  end
  local parts, cur_hl, cur_start = {}, per_col[from] or fallback, from
  for i = from + 1, to do
    local hl = per_col[i] or fallback
    if hl ~= cur_hl then
      parts[#parts + 1] = { line:sub(cur_start, i - 1), cur_hl }
      cur_hl, cur_start = hl, i
    end
  end
  parts[#parts + 1] = { line:sub(cur_start, to), cur_hl }
  return parts
end

function M.foldtext()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_lnum, end_lnum = vim.v.foldstart, vim.v.foldend
  local hidden = end_lnum - start_lnum
  local tail = { "   ↙ [" .. hidden .. " lines hidden]", FOLD_TAIL_HL }

  -- 起始行：未被 capture 覆盖的字节退回 Normal，紧跟原始行一致。
  local start_line = vim.fn.getline(start_lnum)
  local parts = line_to_parts(start_line, collect_ts_highlights(bufnr, start_lnum, #start_line), "")

  -- Markdown 交给 render-markdown.nvim 画标题背景/表格图标，foldtext 一旦接管会覆盖
  -- 它的 hl_eol extmark；这里回退到默认 `foldtext()`，舍弃首末行高亮和尾部提示。
  if vim.bo[bufnr].filetype == "markdown" then
    return vim.fn.foldtext()
  end

  -- 前缀拼接：保留首行原有缩进，把 `◇ ` 拼到缩进尾部；不足两格时直接前置。
  local first = parts[1]
  local leading = first and first[1]:match("^ *") or ""
  if #leading == 0 then
    table.insert(parts, 1, { FOLD_PREFIX, FOLD_PREFIX_HL })
  else
    first[1] = first[1]:sub(#leading + 1)
    if first[1] == "" then
      table.remove(parts, 1)
    end
    local indent = leading:sub(1, math.max(#leading - FOLD_PREFIX_WIDTH, 0))
    table.insert(parts, 1, { FOLD_PREFIX, FOLD_PREFIX_HL })
    if indent ~= "" then
      table.insert(parts, 1, { indent, "" })
    end
  end

  -- 末行预览：去除两端空白后保留语法高亮；parser 缺失时兜底 ConfigFoldPreview。
  local end_line = vim.fn.getline(end_lnum)
  local from, to = end_line:find("%S"), end_line:find("%s*$")
  if from and to - 1 >= from then
    parts[#parts + 1] = { " ⋯ ", FOLD_MUTED_HL }
    for _, seg in ipairs(line_to_parts(end_line, collect_ts_highlights(bufnr, end_lnum, #end_line), FOLD_PREVIEW_HL, from, to - 1)) do
      parts[#parts + 1] = seg
    end
  end

  parts[#parts + 1] = tail
  return parts
end

-- ============================================
-- 安装入口
-- ============================================
function M.setup()
  vim.o.foldmethod = "expr"
  vim.o.foldexpr = "v:lua.require'config.fold'.foldexpr(v:lnum)"
  vim.o.foldtext = "v:lua.require'config.fold'.foldtext()"
end

return M
