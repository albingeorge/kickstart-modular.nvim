-- Small helpers shared by the per-language modules in `lua/custom/lang/`.
local M = {}

--- Ask Mason to install any of `packages` that are missing.
--- Uses Mason *package* names (see `:Mason`), e.g. 'jdtls', 'google-java-format'.
---@param packages string[]
function M.ensure_installed(packages)
  vim.schedule(function()
    local ok, registry = pcall(require, 'mason-registry')
    if not ok then return end

    for _, name in ipairs(packages) do
      if registry.has_package(name) then
        local pkg = registry.get_package(name)
        if not pkg:is_installed() and not pkg:is_installing() then
          vim.notify(('Installing %s...'):format(name), vim.log.levels.INFO)
          pkg:install(nil, function(success, err)
            if not success then vim.notify(('Failed to install %s: %s'):format(name, tostring(err)), vim.log.levels.ERROR) end
          end)
        end
      end
    end
  end)
end

--- Make sure a treesitter parser is installed (highlighting/indent for the language).
---@param parser string
function M.ensure_parser(parser)
  local ok, ts = pcall(require, 'nvim-treesitter')
  if not ok then return end

  if not vim.tbl_contains(ts.get_installed 'parsers', parser) then ts.install(parser) end
end

--- Register external formatters for a filetype with conform.nvim.
--- Conform reads `formatters_by_ft` lazily, so this works after its `setup()` call.
---@param filetype string
---@param formatters table
function M.set_formatters(filetype, formatters)
  local ok, conform = pcall(require, 'conform')
  if not ok then return end

  conform.formatters_by_ft[filetype] = formatters
end

--- Configure and enable a language server, merging on top of nvim-lspconfig's defaults.
---@param name string
---@param config vim.lsp.Config
function M.lsp(name, config)
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

return M

-- vim: ts=2 sts=2 sw=2 et
