local M = {}
local config = require("greyout.config")
local highlights = require("greyout.highlights")

M.enabled = false
M.language_modules = {}

-- Pattern management functions (merged from patterns.lua)
local function has_patterns(filetype)
  local lang_config = config.get_language_config(filetype)
  return lang_config and lang_config.enabled and M.language_modules[filetype] ~= nil
end

local function apply_custom_patterns(bufnr, filetype, root)
  local custom = config.options.custom_patterns[filetype]
  if not custom then return end
  
  local lang = vim.treesitter.language.get_lang(filetype)
  if not lang then return end
  
  for pattern_name, query_string in pairs(custom) do
    local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
    if ok then
      for _, match, _ in query:iter_matches(root, bufnr, 0, -1) do
        for id, node in pairs(match) do
          local start_row, start_col, end_row, end_col = node:range()
          highlights.add_highlight(bufnr, start_row, start_col, end_row, end_col)
        end
      end
    else
      vim.notify("Greyout: Invalid custom pattern '" .. pattern_name .. "': " .. query, vim.log.levels.WARN)
    end
  end
end

local function apply_patterns(bufnr, filetype, root)
  local lang_module = M.language_modules[filetype]
  if not lang_module then return end
  
  if lang_module.apply_patterns then
    lang_module.apply_patterns(bufnr, root)
  end
  
  apply_custom_patterns(bufnr, filetype, root)
end

function M.setup(opts)
  config.setup(opts)
  highlights.setup()
  
  -- Load language modules
  M.language_modules.go = require("greyout.languages.go")
  
  M.setup_commands()
  M.setup_autocmds()
  
  M.setup_keymaps()
  
  if config.options.enabled then
    M.enable()
  end
end

function M.enable()
  if M.enabled then return end
  M.enabled = true
  M.refresh_all()
end

function M.disable()
  if not M.enabled then return end
  M.enabled = false
  
  -- Clear folds if we're in fold mode
  if config.options.mode == "fold" then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      highlights.clear_folds(buf)
    end
  end
  
  M.clear_all()
end

function M.toggle()
  if M.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.refresh_all()
  if not M.enabled then return end
  
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    M.refresh_buffer(buf)
  end
end

function M.refresh_buffer(bufnr)
  if not M.enabled then return end
  
  -- Check if buffer is still valid
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if not has_patterns(ft) then return end
  
  highlights.clear_buffer(bufnr)
  
  -- Set conceallevel if in conceal mode
  if config.options.mode == "conceal" then
    vim.api.nvim_win_set_option(0, "conceallevel", 2)
    vim.api.nvim_win_set_option(0, "concealcursor", "")
  end
  
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
  if not ok or not parser then 
    -- Silently skip if parser not available
    return 
  end
  
  local ok2, trees = pcall(parser.parse, parser)
  if not ok2 or not trees or not trees[1] then return end
  
  local tree = trees[1]
  local root = tree:root()
  
  apply_patterns(bufnr, ft, root)
  
  -- Apply folds if in fold mode
  if config.options.mode == "fold" then
    highlights.apply_folds(bufnr)
  end
end

function M.clear_all()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    highlights.clear_buffer(buf)
  end
end

function M.cycle_mode()
  local current = config.options.mode
  local next_mode
  
  if current == "off" then
    next_mode = "grey"
  elseif current == "grey" then
    next_mode = "conceal"
  elseif current == "conceal" then
    next_mode = "fold"
  else
    next_mode = "off"
  end
  
  -- Clear folds when leaving fold mode
  if current == "fold" and next_mode ~= "fold" then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      highlights.clear_folds(buf)
    end
  end
  
  config.options.mode = next_mode
  
  if next_mode == "off" then
    M.disable()
  else
    if not M.enabled then
      M.enable()
    else
      M.refresh_all()
    end
  end
  
end

function M.set_mode(mode)
  if mode ~= "off" and mode ~= "grey" and mode ~= "conceal" and mode ~= "fold" then
    return
  end
  
  local current = config.options.mode
  
  -- Clear folds when leaving fold mode
  if current == "fold" and mode ~= "fold" then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      highlights.clear_folds(buf)
    end
  end
  
  config.options.mode = mode
  
  if mode == "off" then
    M.disable()
  else
    if not M.enabled then
      M.enable()
    else
      M.refresh_all()
    end
  end
  
end

function M.setup_commands()
  vim.api.nvim_create_user_command("GreyoutToggle", function()
    M.toggle()
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutEnable", function()
    M.enable()
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutDisable", function()
    M.disable()
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutCycle", function()
    M.cycle_mode()
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutMode", function(opts)
    if opts.args ~= "" then
      M.set_mode(opts.args)
    end
  end, {
    nargs = "?",
    complete = function()
      return { "off", "grey", "conceal", "fold" }
    end,
  })
end

function M.setup_keymaps()
  local keymaps = config.options.keymaps
  
  if keymaps.toggle then
    vim.keymap.set("n", keymaps.toggle, function() M.toggle() end, { 
      desc = "Greyout: Toggle",
      silent = true 
    })
  end
  
  if keymaps.cycle then
    vim.keymap.set("n", keymaps.cycle, function() M.cycle_mode() end, { 
      desc = "Greyout: Cycle modes",
      silent = true 
    })
  end
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("Greyout", { clear = true })
  
  -- Refresh on text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    callback = function(args)
      if M.enabled then
        vim.defer_fn(function()
          M.refresh_buffer(args.buf)
        end, 50)  -- Reduced delay for faster response
      end
    end,
  })
  
  -- Refresh when entering a buffer or changing filetype
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      if M.enabled then
        vim.defer_fn(function()
          M.refresh_buffer(args.buf)
        end, 10)
      end
    end,
  })
  
  -- Refresh after colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      if M.enabled then
        config.setup(config.options)  -- Re-apply highlight groups
        M.refresh_all()
      end
    end,
  })
end

return M