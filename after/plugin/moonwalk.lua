-- Use a limited runtimepath to only search user's configuration files. This
-- speeds up the search a bit.
local rtp = vim.o.runtimepath
local t = {vim.fn.stdpath("config"), vim.fn.stdpath("data") .. "/site"}
vim.o.runtimepath = table.concat(t, ",") .. "," .. table.concat(t, "/after,") .. "/after"
for ext in pairs(require("moonwalk").compilers) do
    vim.api.nvim_command(string.format("runtime! plugin/**/*.%s", ext))
end
vim.o.runtimepath = rtp
