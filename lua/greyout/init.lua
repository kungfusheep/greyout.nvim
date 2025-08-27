local M = {}
local config = require("greyout.config")
local highlights = require("greyout.highlights")
local patterns = require("greyout.patterns")

M.enabled = false
M.namespaces = {}

function M.setup(opts)
  config.setup(opts)
  highlights.setup()
  patterns.setup()
  
  M.setup_commands()
  M.setup_autocmds()
  
  if config.options.keymaps.enabled then
    M.setup_keymaps()
  end
  
  if config.options.auto_enable then
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
  if not patterns.has_patterns(ft) then return end
  
  highlights.clear_buffer(bufnr)
  
  -- Set conceallevel if in conceal mode
  if config.options.mode == "conceal" then
    vim.api.nvim_win_set_option(0, "conceallevel", 2)
    if config.options.conceal.show_on_cursor then
      vim.api.nvim_win_set_option(0, "concealcursor", "")
    else
      vim.api.nvim_win_set_option(0, "concealcursor", "nvic")
    end
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
  
  patterns.apply_patterns(bufnr, ft, root)
  
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
  
  vim.notify("Greyout mode: " .. next_mode)
end

function M.set_mode(mode)
  if mode ~= "off" and mode ~= "grey" and mode ~= "conceal" and mode ~= "fold" then
    vim.notify("Invalid mode. Use 'off', 'grey', 'conceal', or 'fold'", vim.log.levels.ERROR)
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
  
  vim.notify("Greyout mode: " .. mode)
end

function M.setup_commands()
  vim.api.nvim_create_user_command("GreyoutToggle", function()
    M.toggle()
    vim.notify("Greyout " .. (M.enabled and "enabled" or "disabled"))
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutEnable", function()
    M.enable()
    vim.notify("Greyout enabled")
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutDisable", function()
    M.disable()
    vim.notify("Greyout disabled")
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutRefresh", function()
    M.refresh_all()
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutCycle", function()
    M.cycle_mode()
  end, {})
  
  vim.api.nvim_create_user_command("GreyoutMode", function(opts)
    if opts.args == "" then
      vim.notify("Current mode: " .. config.options.mode)
    else
      M.set_mode(opts.args)
    end
  end, {
    nargs = "?",
    complete = function()
      return { "off", "grey", "conceal", "fold" }
    end,
  })
  
  vim.api.nvim_create_user_command("GreyoutStatus", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    print("Greyout Status:")
    print("  Enabled: " .. tostring(M.enabled))
    print("  Filetype: " .. ft)
    print("  Has patterns: " .. tostring(patterns.has_patterns(ft)))
    
    if ft == "go" then
      local lang_config = config.get_language_config("go")
      if lang_config then
        print("  Go config:")
        print("    Enabled: " .. tostring(lang_config.enabled))
        print("    Error handling: " .. tostring(lang_config.patterns.error_handling))
        print("    Logging: " .. tostring(lang_config.patterns.logging))
        print("    Debug: " .. tostring(lang_config.patterns.debug))
      end
    end
  end, {})
end

function M.setup_keymaps()
  local prefix = config.options.keymaps.prefix
  local mappings = config.options.keymaps.mappings
  
  local function map(suffix, cmd, desc)
    vim.keymap.set("n", prefix .. suffix, cmd, { 
      desc = "Greyout: " .. desc,
      silent = true 
    })
  end
  
  -- Set up keymaps
  map(mappings.toggle, function() M.toggle() end, "Toggle on/off")
  map(mappings.cycle, function() M.cycle_mode() end, "Cycle modes")
  map(mappings.grey, function() M.set_mode("grey") end, "Grey mode")
  map(mappings.conceal, function() M.set_mode("conceal") end, "Hide/conceal mode")
  map(mappings.fold, function() M.set_mode("fold") end, "Fold mode (collapses lines)")
  map(mappings.off, function() M.set_mode("off") end, "Turn off")
  map(mappings.refresh, function() M.refresh_all() end, "Refresh")
  
  -- Also add a which-key friendly description for the prefix
  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.register({
      [prefix] = { name = "+greyout" }
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