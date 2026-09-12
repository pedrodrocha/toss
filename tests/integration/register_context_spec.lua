package.path = "./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;" .. package.path
vim.opt.rtp:prepend(vim.fn.getcwd())

local test = require("tests.testlib")
local result = require("toss.result")
local toss = require("toss")

local fixture_path = vim.fn.getcwd() .. "/.toss-register-fixture"
vim.fn.writefile({ "one", "two", "three", "four" }, fixture_path)

local calls = {}
local transport = {
  send = function(direction, text)
    calls[#calls + 1] = { direction = direction, text = text }
    return result.ok()
  end,
}

toss.config = {}
toss.setup({ transport = transport, mappings = true })

local function edit_fixture()
  vim.cmd("edit! " .. vim.fn.fnameescape(fixture_path))
end

local function toss_text()
  test.equal(toss.right(), true)
  return calls[#calls].text
end

local function toss_yank_text()
  local leader = vim.g.mapleader or "\\"
  local key = vim.api.nvim_replace_termcodes(leader .. "tyl", true, false, true)
  local previous_calls = #calls
  vim.api.nvim_feedkeys(key, "xt", false)
  test.equal(#calls, previous_calls + 1)
  return calls[#calls].text
end

local function leave_visual_mode()
  local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(escape, "nx", false)
end

test.describe("tracked unnamed register context", function()
  test.it("installs one TextYankPost observer across repeated setup", function()
    toss.setup({ transport = transport, mappings = true })
    toss.setup({ transport = transport, mappings = true })

    local autocmds = vim.api.nvim_get_autocmds({
      group = "TossRegisterContext",
      event = "TextYankPost",
    })
    test.equal(#autocmds, 1)
  end)

  test.it("keeps direct Normal file tossing when no register context exists", function()
    edit_fixture()
    vim.cmd("normal! gg")

    test.equal(toss_text(), "@.toss-register-fixture")
  end)

  test.it("formats a characterwise yank using its inclusive source range", function()
    edit_fixture()
    vim.cmd("normal! gg0vjjy")

    test.equal(toss_yank_text(), "@.toss-register-fixture#L1-L3")
    test.equal(toss_text(), "@.toss-register-fixture")
  end)

  test.it("formats a reverse linewise yank with normalized lines", function()
    edit_fixture()
    vim.cmd("normal! 4GVkkky")

    test.equal(toss_yank_text(), "@.toss-register-fixture#L1-L4")
  end)

  test.it("keeps black-hole operations from replacing the current context", function()
    edit_fixture()
    vim.cmd("normal! 2Gyy")
    test.equal(toss_yank_text(), "@.toss-register-fixture#L2-L2")

    vim.cmd("normal! gg\"_yy")
    test.equal(toss_yank_text(), "@.toss-register-fixture#L2-L2")
  end)

  test.it("tracks delete and change source ranges", function()
    edit_fixture()
    vim.cmd("normal! 2Gdd")
    test.equal(toss_yank_text(), "@.toss-register-fixture#L2-L2")

    edit_fixture()
    vim.cmd("normal! 3Gcc")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("replacement<Esc>", true, false, true), "xt", false)
    test.equal(toss_yank_text(), "@.toss-register-fixture#L3-L3")
  end)

  test.it("lets an active Visual file context override an older register", function()
    edit_fixture()
    vim.cmd("normal! 4Gyy")

    vim.cmd("normal! ggVj")
    test.equal(toss_text(), "@.toss-register-fixture#L1-L2")
    leave_visual_mode()
  end)

  test.it("sends non-file register text literally and preserves it for paste", function()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "literal line", "another line" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! yy")

    local register_text = vim.fn.getreg('"')
    local register_type = vim.fn.getregtype('"')
    test.equal(toss_yank_text(), register_text)
    test.equal(vim.fn.getreg('"'), register_text)
    test.equal(vim.fn.getregtype('"'), register_type)

    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "paste target" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! p")
    test.equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[2], "literal line")
  end)

  test.it("sends a metadata-free register change literally", function()
    edit_fixture()
    vim.cmd("normal! 2Gyy")
    vim.fn.setreg('"', "literal\ntext", "v")

    test.equal(toss_yank_text(), "literal\ntext")
  end)
end)

vim.fn.delete(fixture_path)
test.finish()
