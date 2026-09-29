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
--
-- Optional extras, install them yourself when you want them:
--    :MasonInstall java-debug-adapter java-test
-- They are picked up automatically as jdtls bundles (see `bundles` below) and
-- unlock <leader>dm / <leader>dc / <leader>dt. Debugging additionally needs
-- `kickstart.plugins.debug` enabled in `lua/plugins.lua` (nvim-dap).
local lang = require 'custom.lang.util'

lang.ensure_installed { 'jdtls', 'google-java-format' }
lang.ensure_parser 'java'

-- nvim-jdtls wraps the language server with the JDT-specific extensions that
-- plain LSP has no notion of: organize imports, extract variable/method,
-- generate constructors/toString, and the test/debug bundles.
--
-- Because of that we do *not* use `lang.lsp('jdtls', ...)` here — the server is
-- started per-buffer from the `FileType java` autocommand below, so that each
-- project gets its own workspace and the extended client capabilities are
-- announced during initialize.
vim.pack.add { 'https://github.com/mfussenegger/nvim-jdtls' }

local mason = vim.fn.stdpath 'data' .. '/mason'
local lombok_path = mason .. '/packages/jdtls/lombok.jar'

--- Collect the `.jar` bundles jdtls should load (debug + test support).
--- Missing packages are simply skipped, so this works before/without them.
---@return string[]
local function bundles()
  local jars = {}

  vim.list_extend(jars, vim.fn.glob(mason .. '/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar', true, true))
  -- The test extension ships jars that must *not* be passed to jdtls (they are
  -- runtime dependencies of the test runner, not JDT plugins).
  vim.list_extend(
    jars,
    vim.tbl_filter(
      function(jar) return not jar:match 'com%.microsoft%.java%.test%.runner%-jar%-with%-dependencies%.jar$' and not jar:match 'jacoco' end,
      vim.fn.glob(mason .. '/packages/java-test/extension/server/*.jar', true, true)
    )
  )

  return jars
end

--- Per-project workspace directory, keyed by the project root's name.
---@param root string
---@return string
local function workspace_dir(root) return vim.fn.stdpath 'cache' .. '/jdtls/' .. vim.fn.fnamemodify(root, ':p:h:t') end

--- m2e lifecycle-mapping overrides, passed to jdtls via
--- `java.configuration.maven.lifecycleMappings`. With
--- `defaultMojoExecutionAction = 'execute'` below, m2e would otherwise run
--- *every* unmapped plugin inside the jdtls JVM — including formatters. Those
--- are unwanted in the editor (they rewrite files behind your back) and often
--- crash anyway: google-java-format needs `--add-exports jdk.compiler/...`,
--- which projects supply via `.mvn/jvm.config`, a file m2e never reads.
---
--- Generated from here so this file stays the single place Java lives.
---@return string path to the metadata XML
local function lifecycle_mappings()
  local path = vim.fn.stdpath 'cache' .. '/jdtls/lifecycle-mapping-metadata.xml'
  local ignored = {
    { 'com.cosium.code', 'git-code-format-maven-plugin', { 'format-code', 'validate-code-format', 'install-hooks', 'on-pre-commit' } },
    { 'com.spotify.fmt', 'fmt-maven-plugin', { 'format', 'check' } },
    { 'com.diffplug.spotless', 'spotless-maven-plugin', { 'apply', 'check' } },
  }

  local lines = { '<?xml version="1.0" encoding="UTF-8"?>', '<lifecycleMappingMetadata>', '  <pluginExecutions>' }
  for _, p in ipairs(ignored) do
    vim.list_extend(lines, {
      '    <pluginExecution>',
      '      <pluginExecutionFilter>',
      '        <groupId>' .. p[1] .. '</groupId>',
      '        <artifactId>' .. p[2] .. '</artifactId>',
      '        <versionRange>[0,)</versionRange>',
      '        <goals>',
    })
    vim.list_extend(lines, vim.tbl_map(function(g) return '          <goal>' .. g .. '</goal>' end, p[3]))
    vim.list_extend(lines, { '        </goals>', '      </pluginExecutionFilter>', '      <action><ignore/></action>', '    </pluginExecution>' })
  end
  vim.list_extend(lines, { '  </pluginExecutions>', '</lifecycleMappingMetadata>' })

  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(lines, path)
  return path
end

--- Find the directory jdtls should import as the workspace root.
---
--- The nearest `pom.xml` is only right for single-module builds. In a Maven
--- reactor it is the module's own pom, so jdtls imports that one module alone
--- and sibling modules resolve from ~/.m2. An unreleased -SNAPSHOT is missing
--- there, which leaves every import from a sibling module unresolved. Climbing
--- to the outermost contiguous `pom.xml` imports the whole reactor, and m2e
--- then links siblings as workspace projects.
---@param bufnr integer
---@return string
local function find_root(bufnr)
  local root = vim.fs.root(bufnr, { 'settings.gradle', 'settings.gradle.kts', 'mvnw', 'gradlew' })
  if root then return root end

  local pom = vim.fs.root(bufnr, 'pom.xml')
  if pom then
    for dir in vim.fs.parents(pom) do
      if not vim.uv.fs_stat(dir .. '/pom.xml') then break end
      pom = dir
    end
    return pom
  end

  return vim.fs.root(bufnr, { 'build.gradle', 'build.gradle.kts', '.git' }) or vim.fn.getcwd()
end

local function jdtls_config(bufnr)
  local root = find_root(bufnr)

  ---@type table
  local config = {
    name = 'jdtls',

    -- Mason's `jdtls` wrapper already picks the right launcher jar and
    -- platform config directory; we only add the data dir and Lombok.
    cmd = {
      mason .. '/bin/jdtls',
      '-data',
      workspace_dir(root),
      '--jvm-arg=-javaagent:' .. lombok_path,
    },

    root_dir = root,

    settings = {
      java = {
        format = { enabled = false },
        signatureHelp = { enabled = true },
        inlayHints = { parameterNames = { enabled = 'all' } },
        configuration = {
          updateBuildConfiguration = 'automatic',
          maven = {
            -- jdtls imports Maven projects through m2e, which only runs a
            -- plugin execution during import if it has lifecycle-mapping
            -- metadata for it. The default action for an unmapped execution is
            -- 'ignore', which is what produces
            --   "Plugin execution not covered by lifecycle configuration: ..."
            -- and, worse, means code generators never run *and* never get to
            -- call project.addCompileSourceRoot(...) — so their output under
            -- target/generated-sources is invisible to the language server and
            -- every import of a generated class is unresolved.
            --
            -- 'execute' makes m2e run those executions during project
            -- configuration, which registers the generated source roots, but
            -- only for plugins m2e actually has a connector for. Plugins
            -- without one (e.g. graphql-maven-plugin) still won't register
            -- their source roots this way — wrap them with
            -- build-helper-maven-plugin's add-source goal in the pom instead.
            -- 'ignore' | 'warn' | 'error' | 'execute'
            defaultMojoExecutionAction = 'execute',
            -- ...except for formatters, see `lifecycle_mappings()`.
            lifecycleMappings = lifecycle_mappings(),
          },
        },
        completion = {
          favoriteStaticMembers = {
            'org.junit.jupiter.api.Assertions.*',
            'org.junit.Assert.*',
            'org.mockito.Mockito.*',
            'java.util.Objects.requireNonNull',
          },
          importOrder = { 'java', 'javax', 'com', 'org' },
        },

        sources = {
          organizeImports = {
            starThreshold = 9999,
            staticStarThreshold = 9999,
          },
        },
        codeGeneration = {
          toString = {
            template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
          },
          useBlocks = true,
        },
      },
    },

    -- `extendedClientCapabilities` is what tells jdtls this client understands
    -- the non-standard requests nvim-jdtls implements.
    init_options = {
      bundles = bundles(),
      extendedClientCapabilities = vim.tbl_deep_extend('force', require('jdtls').extendedClientCapabilities, {
        resolveAdditionalTextEditsSupport = true,
      }),
    },
  }

  -- blink.cmp advertises richer completion capabilities than the defaults; the
  -- global `vim.lsp.config('*')` merge does not reach a manually started client.
  local ok, blink = pcall(require, 'blink.cmp')
  if ok then config.capabilities = blink.get_lsp_capabilities() end

  return config
end

local group = vim.api.nvim_create_augroup('custom-lang-java', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'java',
  callback = function(event)
    -- Java files conventionally use 4 spaces; `guess-indent.nvim` will still
    -- win for projects that disagree.
    vim.bo[event.buf].expandtab = true
    vim.bo[event.buf].shiftwidth = 4
    vim.bo[event.buf].tabstop = 4
    vim.bo[event.buf].softtabstop = 4

    local ok, jdtls = pcall(require, 'jdtls')
    if not ok then
      vim.notify('nvim-jdtls is not installed yet; restart Neovim after :lua vim.pack.update()', vim.log.levels.WARN)
      return
    end

    -- Reuses an already running client when the root dir matches, so opening a
    -- second file in the same project does not spawn a second server.
    jdtls.start_or_attach(jdtls_config(event.buf))
  end,
})

-- Buffer-local keymaps for the jdtls-only features. Registered on attach so
-- they never shadow anything in non-Java buffers.
vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= 'jdtls' then return end

    local jdtls = require 'jdtls'
    local map = function(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'Java: ' .. desc }) end

    map('<leader>jo', jdtls.organize_imports, '[O]rganize imports')
    map('<leader>jv', jdtls.extract_variable, 'Extract [V]ariable')
    map('<leader>jv', function() jdtls.extract_variable(true) end, 'Extract [V]ariable', 'v')
    map('<leader>jc', jdtls.extract_constant, 'Extract [C]onstant')
    map('<leader>jc', function() jdtls.extract_constant(true) end, 'Extract [C]onstant', 'v')
    map('<leader>jm', function() jdtls.extract_method(true) end, 'Extract [M]ethod', 'v')

    -- Test/debug entry points; they need the java-test and java-debug-adapter
    -- bundles (and nvim-dap) to be present.
    if pcall(require, 'dap') then
      map('<leader>dm', jdtls.test_nearest_method, 'Debug nearest [M]ethod')
      map('<leader>dc', jdtls.test_class, 'Debug test [C]lass')
    end
  end,
})

lang.set_formatters('java', { 'google-java-format' })

-- vim: ts=2 sts=2 sw=2 et
