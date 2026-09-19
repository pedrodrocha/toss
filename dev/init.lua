local source = debug.getinfo(1, "S").source
local init_path = source:sub(1, 1) == "@" and source:sub(2) or source
local repository_root = vim.fn.fnamemodify(init_path, ":p:h:h")
local lua_root = repository_root .. "/lua"

-- Remove mappings owned by the previous development load before discarding its
-- in-memory ownership state.
local previous_toss = package.loaded["toss"]
if type(previous_toss) == "table" and type(previous_toss.setup) == "function" then
  pcall(previous_toss.setup, { mappings = false })
end

for module_name in pairs(package.loaded) do
  if module_name == "toss" or module_name:match("^toss%.") then
    package.loaded[module_name] = nil
  end
end

vim.opt.rtp:prepend(repository_root)
package.path = table.concat({
  lua_root .. "/?.lua",
  lua_root .. "/?/init.lua",
  package.path,
}, ";")

local toss = require("toss")
toss.setup({ transport = "auto", mappings = true, which_key = true })

-- Configure the optional Telescope file-browser integration when Telescope is
-- available. This only affects the current development session.
local telescope_ok, telescope = pcall(require, "telescope")
if telescope_ok then
  local file_browser_mappings = require("toss.integrations.telescope.file_browser").mappings()

  telescope.setup({
    extensions = {
      file_browser = {
        initial_mode = "normal",
        mappings = file_browser_mappings,
      },
    },
  })

  pcall(telescope.load_extension, "file_browser")
end

vim.notify(
  "toss: development source loaded from " .. repository_root .. " (transport: auto, mappings, which-key: optional)",
  vim.log.levels.INFO
)
