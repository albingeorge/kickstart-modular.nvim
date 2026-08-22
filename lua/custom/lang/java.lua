-- [[ Java ]]
--
-- Everything Java-specific lives in this one file. Delete it and Java support
-- is gone; nothing else in the config refers to it.
--
-- Requires a JDK 21+ on your PATH (jdtls itself runs on the JVM):
--    macOS:  brew install openjdk@21
--    check:  java -version
--
-- Tooling is installed by Mason on first start (:Mason to watch progress):
--    jdtls               - Eclipse JDT language server
--    google-java-format  - formatter, run with <leader>f
local lang = require 'custom.lang.util'

lang.ensure_installed { 'jdtls', 'google-java-format' }
lang.ensure_parser 'java'

-- nvim-lspconfig ships `lsp/jdtls.lua`, which already picks the right root
-- directory (mvnw/gradlew/pom.xml/...) and gives each project its own jdtls
-- data directory under `stdpath('cache')/jdtls`. We only add settings on top.
--
-- NOTE: For the full jdtls feature set (organize imports, extract variable,
-- test running, debugging) install https://github.com/mfussenegger/nvim-jdtls
-- and start it from a `FileType java` autocommand instead of enabling it here.
lang.lsp('jdtls', {
  settings = {
    java = {
      -- Format with google-java-format via conform instead of jdtls.
      format = { enabled = false },
      signatureHelp = { enabled = true },
      -- Show type hints for parameters at call sites.
      inlayHints = { parameterNames = { enabled = 'all' } },
      -- Let jdtls suggest imports for these, even without an existing import.
      completion = {
        favoriteStaticMembers = {
          'org.junit.jupiter.api.Assertions.*',
          'org.junit.Assert.*',
          'org.mockito.Mockito.*',
          'java.util.Objects.requireNonNull',
        },
        importOrder = { 'java', 'javax', 'com', 'org' },
      },
      -- Generated code style for the source actions jdtls offers.
      sources = {
        organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
      },
      codeGeneration = {
        toString = { template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}' },
        useBlocks = true,
      },
    },
  },
})

lang.set_formatters('java', { 'google-java-format' })

-- Java files conventionally use 4 spaces; `guess-indent.nvim` will still win
-- for projects that disagree.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('custom-lang-java', { clear = true }),
  pattern = 'java',
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})

-- vim: ts=2 sts=2 sw=2 et
