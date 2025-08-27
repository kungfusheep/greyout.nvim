local M = {}
local highlights = require("greyout.highlights")
local config = require("greyout.config")

M.queries = {
  -- Match if var != nil patterns without predicates
  error_handling = [[
    (if_statement
      (binary_expression
        (identifier) @var
        "!="
        (nil))
      (block) @error_block) @if_stmt
  ]],
  
  -- Match fmt and log calls without predicates
  logging = [[
    (call_expression
      function: (selector_expression
        operand: (identifier) @pkg
        field: (field_identifier) @method)) @log_call
  ]],
  
  -- Match direct log.* calls (when log is imported with .)
  logging_direct = [[
    (call_expression
      function: (identifier) @func) @log_call
  ]],
}

function M.apply_patterns(bufnr, root)
  local lang = vim.treesitter.language.get_lang("go")
  if not lang then 
    return 
  end
  
  local matches_found = 0
  
  -- Process error handling patterns
  if config.is_pattern_enabled("go", "error_handling") then
    local ok, query = pcall(vim.treesitter.query.parse, lang, M.queries.error_handling)
    if ok then
      for _, match in query:iter_matches(root, bufnr, 0, -1) do
        local var_text = nil
        local if_stmt_node = nil
        
        for id, nodes in pairs(match) do
          if type(id) == "number" and type(nodes) == "table" then
            local capture = query.captures[id]
            local node = nodes[1]
            
            if capture == "var" and node then
              var_text = vim.treesitter.get_node_text(node, bufnr)
            elseif capture == "if_stmt" and node then
              if_stmt_node = node
            end
          end
        end
        
        -- Check if it's an error variable
        if var_text and if_stmt_node and (var_text == "err" or var_text == "error" or var_text == "e") then
          local start_row, start_col, end_row, end_col = if_stmt_node:range()
          highlights.add_highlight(bufnr, start_row, start_col, end_row, end_col)
          matches_found = matches_found + 1
        end
      end
    end
  end
  
  -- Process logging patterns
  if config.is_pattern_enabled("go", "logging") then
    -- Match selector-style calls (fmt.Print, log.Info, etc)
    local ok, query = pcall(vim.treesitter.query.parse, lang, M.queries.logging)
    if ok then
      for _, match in query:iter_matches(root, bufnr, 0, -1) do
        local pkg_text = nil
        local method_text = nil
        local call_node = nil
        
        for id, nodes in pairs(match) do
          if type(id) == "number" and type(nodes) == "table" then
            local capture = query.captures[id]
            local node = nodes[1]
            
            if capture == "pkg" and node then
              pkg_text = vim.treesitter.get_node_text(node, bufnr)
            elseif capture == "method" and node then
              method_text = vim.treesitter.get_node_text(node, bufnr)
            elseif capture == "log_call" and node then
              call_node = node
            end
          end
        end
        
        -- Check if it's fmt or log package
        if pkg_text and call_node then
          local should_highlight = false
          
          if pkg_text == "fmt" then
            -- For fmt, only highlight direct Print calls (likely debug output)
            -- Skip Sprintf, Errorf etc as they're often part of business logic
            should_highlight = method_text and (
              method_text == "Print" or 
              method_text == "Printf" or
              method_text == "Println"
            )
          elseif pkg_text == "log" or pkg_text == "logger" then
            -- For log/logger, highlight everything except New* or Set*
            should_highlight = method_text and not (
              method_text:match("^New") or 
              method_text:match("^Set") or
              method_text:match("^Get")
            )
          end
          
          if should_highlight then
            local start_row, start_col, end_row, end_col = call_node:range()
            highlights.add_highlight(bufnr, start_row, start_col, end_row, end_col)
            matches_found = matches_found + 1
          end
        end
      end
    end
    
    -- Also match direct function calls that look like logging
    local ok2, query2 = pcall(vim.treesitter.query.parse, lang, M.queries.logging_direct)
    if ok2 then
      for _, match in query2:iter_matches(root, bufnr, 0, -1) do
        local func_text = nil
        local call_node = nil
        
        for id, nodes in pairs(match) do
          if type(id) == "number" and type(nodes) == "table" then
            local capture = query2.captures[id]
            local node = nodes[1]
            
            if capture == "func" and node then
              func_text = vim.treesitter.get_node_text(node, bufnr)
            elseif capture == "log_call" and node then
              call_node = node
            end
          end
        end
        
        -- Check if it's a logging function (Print, Debug, Info, etc when log is imported with .)
        if func_text and call_node and func_text:match("^(Print|Printf|Println|Debug|Debugf|Info|Infof|Warn|Warnf|Error|Errorf|Fatal|Fatalf|Log|Logf)$") then
          local start_row, start_col, end_row, end_col = call_node:range()
          highlights.add_highlight(bufnr, start_row, start_col, end_row, end_col)
          matches_found = matches_found + 1
        end
      end
    end
  end
end

return M