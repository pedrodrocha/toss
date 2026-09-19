---@class TossTelescopeApi
---@field active_picker fun(prompt_bufnr: integer|nil): TossResult<table>
---@field selected_entry fun(): TossResult<table>
---@field cursor_entry fun(): TossResult<table>
---@field multi_selection fun(picker: table|nil): TossResult<table[]>

local errors = require("toss.errors")
local result = require("toss.result")

local M = {}

local action_state_module = "telescope.actions.state"

---@return TossResult<table>
local function load_action_state()
  local ok, action_state = pcall(require, action_state_module)
  if not ok then
    return result.err(errors.telescope_unavailable(action_state))
  end

  return result.ok(action_state)
end

---@return integer|nil
local function current_buffer()
  if vim == nil or vim.api == nil or vim.api.nvim_get_current_buf == nil then
    return nil
  end

  local ok, bufnr = pcall(vim.api.nvim_get_current_buf)
  if ok then
    return bufnr
  end

  return nil
end

---@param prompt_bufnr integer|nil
---@return TossResult<table>
function M.active_picker(prompt_bufnr)
  local state_result = load_action_state()
  if state_result:is_err() then
    return result.err(state_result.error)
  end

  prompt_bufnr = prompt_bufnr or current_buffer()

  local ok, picker = pcall(function()
    return state_result.value.get_current_picker(prompt_bufnr)
  end)

  if not ok then
    return result.err(errors.telescope_picker(picker))
  end

  if picker == nil then
    return result.err(errors.telescope_picker())
  end

  return result.ok(picker)
end

---@return TossResult<table>
function M.selected_entry()
  local state_result = load_action_state()
  if state_result:is_err() then
    return result.err(state_result.error)
  end

  local ok, entry = pcall(function()
    return state_result.value.get_selected_entry()
  end)
  if not ok then
    return result.err(errors.telescope_entry(entry))
  end

  if entry == nil then
    return result.err(errors.telescope_entry())
  end

  return result.ok(entry)
end

M.cursor_entry = M.selected_entry

---@param picker table|nil
---@return TossResult<table[]>
function M.multi_selection(picker)
  if picker == nil then
    local picker_result = M.active_picker()
    if picker_result:is_err() then
      return result.err(picker_result.error)
    end

    picker = picker_result.value
  end

  local ok, selections = pcall(function()
    return picker:get_multi_selection()
  end)
  if not ok then
    return result.err(errors.telescope_selection(selections))
  end

  if selections == nil then
    return result.err(errors.telescope_selection())
  end

  return result.ok(selections)
end

return M
