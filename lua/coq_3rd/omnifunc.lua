local kind_map =
  (function()
  local lsp_kinds = vim.lsp.protocol.CompletionItemKind

  local acc = {
    v = lsp_kinds.Variable,
    f = lsp_kinds.Function,
    m = lsp_kinds.Property,
    t = lsp_kinds.TypeParameter
    --d = lsp_kinds.Macro
  }

  for key, val in pairs(lsp_kinds) do
    if type(key) == "string" and type(val) == "number" then
      acc[string.lower(key)] = val
    end
  end

  return acc
end)()

local completefunc_items = function(matches)
  vim.validate {
    matches = {matches, "table"}
  }

  local words = matches.words and matches.words or matches

  local parse = function(match)
    vim.validate {
      match = {match, "table"},
      word = {match.word, "string"},
      abbr = {match.abbr, "string", nil},
      menu = {match.menu, "string", nil},
      kind = {match.kind, "string", nil},
      info = {match.info, "string", nil}
    }

    local label = (function()
      local label = match.abbr or match.word
      return match.menu and label .. "\t" .. match.menu or label
    end)()

    local kind = (function()
      local lkind = string.lower(match.kind or "")
      return kind_map[lkind]
    end)()

    local detail = (function()
      if match.info then
        return match.info
      elseif match.kind and not kind then
        return match.kind
      else
        return nil
      end
    end)()

    local item = {
      label = label,
      insertText = match.word,
      kind = kind,
      detail = detail
    }

    return item
  end

  local acc = {}
  for _, match in ipairs(words) do
    local item = parse(match)
    table.insert(acc, item)
  end

  return acc
end

local omnifunc = function(opts)
  vim.validate {
    use_cache = {opts.use_cache, "boolean"},
    omnifunc = {opts.omnifunc, "string"},
    filetypes = {opts.filetypes, "table", true}
  }

  local filetypes = (function()
    local acc = {}
    for _, ft in ipairs(opts.filetypes or {}) do
      vim.validate {ft = {ft, "string"}}
      acc[ft] = true
    end
    return acc
  end)()

  local omnifunc = (function()
    local vlua = "v:lua."
    if vim.startswith(opts.omnifunc, vlua) then
      local name = string.sub(opts.omnifunc, #vlua + 1)
      return function(...)
        return _G[name](...)
      end
    else
      return function(...)
        return vim.call(opts.omnifunc, ...)
      end
    end
  end)()

  local fetch = function(row, col)
    local pos = omnifunc(1, "")
    vim.validate {pos = {pos, "number"}}

    if pos == -2 or pos == -3 then
      return nil
    else
      local cword =
        (function()
        if pos < 0 or pos >= col then
          return vim.fn.expand("<cword>")
        else
          local line =
            vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
          local sep = math.min(col, pos) + 1
          local b_search = string.sub(line, 0, sep)
          local f_search = string.sub(line, sep)
          local f =
            string.reverse(
            string.match(string.reverse(b_search), "^[^%s]+") or ""
          )
          local b = string.match(f_search, "[^%s]+") or ""

          local cword = f .. b
          return cword
        end
      end)()

      local matches = omnifunc(0, cword) or {}
      local items = completefunc_items(matches)

      return {isIncomplete = not opts.use_cache, items = items}
    end
  end

  local wrapped = function(row, col)
    if not opts.filetypes or filetypes[vim.bo.filetype] then
      return fetch(row, col)
    else
      return nil
    end
  end

  return wrapped
end

local wrap = function(opts)
  local omni = omnifunc(opts)
  return function(arg, callback)
    local row, col = unpack(arg.pos)
    local items = omni(row, col)
    callback(items)
  end
end

return wrap