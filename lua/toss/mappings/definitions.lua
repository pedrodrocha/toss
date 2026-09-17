---@class TossMappingDefinition
---@field name string
---@field key string
---@field direction TossDirection
---@field origin TossOrigin
---@field description string

---@type TossMappingDefinition[]
return {
  {
    name = "left",
    key = "<leader>th",
    direction = "left",
    origin = "file_buffer",
    description = "Toss left",
  },
  {
    name = "down",
    key = "<leader>tj",
    direction = "down",
    origin = "file_buffer",
    description = "Toss down",
  },
  {
    name = "up",
    key = "<leader>tk",
    direction = "up",
    origin = "file_buffer",
    description = "Toss up",
  },
  {
    name = "right",
    key = "<leader>tl",
    direction = "right",
    origin = "file_buffer",
    description = "Toss right",
  },
  {
    name = "yank_left",
    key = "<leader>tyh",
    direction = "left",
    origin = "yank",
    description = "Toss yank left",
  },
  {
    name = "yank_down",
    key = "<leader>tyj",
    direction = "down",
    origin = "yank",
    description = "Toss yank down",
  },
  {
    name = "yank_up",
    key = "<leader>tyk",
    direction = "up",
    origin = "yank",
    description = "Toss yank up",
  },
  {
    name = "yank_right",
    key = "<leader>tyl",
    direction = "right",
    origin = "yank",
    description = "Toss yank right",
  },
}
