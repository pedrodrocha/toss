local source = debug.getinfo(1, "S").source
local init_path = source:sub(1, 1) == "@" and source:sub(2) or source
local repository_root = vim.fn.fnamemodify(init_path, ":p:h:h")
local lua_root = repository_root .. "/lua"

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

vim.notify(
  "toss: development source loaded from " .. repository_root .. " (transport: auto, which-key: optional)",
  vim.log.levels.INFO
)
