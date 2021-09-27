-- Copyright (C) 2021 Gregory Anders
--
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local M = {}
local loaders = {}
local cachedir = vim.fn.stdpath("cache")

local log = (function()
    local logfile = assert(io.open(cachedir .. "/moonwalk.log", "a"))
    return function(msg)
        logfile:write(string.format("[%s] %s\n", os.date("%F %T"), msg))
        logfile:flush()
    end
end)()

-- TODO: Rewrite this when autocommands are supported natively in Lua
local function setup_autocmds(ext)
    vim.cmd(string.format(
        [[
augroup moonwalk_%s
    autocmd!
    autocmd SourceCmd *.%s call v:lua.moonwalk.source(expand('<amatch>:p'))
    autocmd FileType * ++nested call v:lua.moonwalk.handle_filetype('%s')
augroup END]],
        ext,
        ext,
        ext
    ))
end

local function compile(path)
    local ext = path:match("[^/.]%.(.-)$")
    local func = loaders[ext].func
    local luapath = cachedir .. "/moonwalk" .. path:gsub("%." .. ext .. "$", ".lua")
    local s = vim.loop.fs_stat(luapath)
    if not s or s.mtime.sec < vim.loop.fs_stat(path).mtime.sec then
        local src = assert(io.open(path, "r"))
        local input = src:read("*a")
        src:close()

        local ok, output = pcall(func, input, path)
        if not ok then
            log(output)
            error(output, 0)
        end

        vim.fn.mkdir(luapath:match("(.+)/.-%.lua"), "p")

        local dst = assert(io.open(luapath, "w"))
        dst:write(output)
        dst:close()
        log(string.format("Compiled %s to %s", path, luapath))
    end
    return luapath
end

local function get_user_runtime_file(name, all, after, rtp)
    if not rtp then
        rtp = { vim.fn.stdpath("config"), vim.fn.stdpath("data") .. "/site" }
        if after then
            for i = 1, #rtp do
                table.insert(rtp, rtp[i] .. "/after")
            end
        end
    end

    local path = table.concat(rtp, ",")
    local found = {}
    for _, n in ipairs(vim.split(name, "%s+")) do
        for _, file in ipairs(vim.fn.globpath(path, n, false, true)) do
            if not all then
                return {file}
            end
            table.insert(found, file)
        end
    end

    return found
end

local function source(path)
    if not path or path == "" then
        return
    end

    local ok, result = pcall(compile, path)
    if ok then
        vim.api.nvim_command("source " .. result)
    else
        vim.notify(result, vim.log.levels.ERROR)
    end
end

local function load_after_plugins()
    for ext in pairs(loaders) do
        local plugins = get_user_runtime_file(string.format("after/plugin/**/*.%s", ext), true, false)
        for _, v in pairs(plugins) do
            source(v)
        end
    end
end

local function handle_filetype(ext)
    local s = vim.fn.expand("<amatch>")
    for name in vim.gsplit(s or "", ".", true) do
        if name then
            local files = get_user_runtime_file(
                string.format(
                    "ftplugin/%s.%s ftplugin/%s_*.%s ftplugin/%s/*.%s indent/%s.%s",
                    name,
                    ext,
                    name,
                    ext,
                    name,
                    ext,
                    name,
                    ext
                ),
                true,
                true
            )

            for _, v in pairs(files) do
                source(v)
            end
        end
    end
end

local function loader(name)
    local basename = name:gsub("%.", "/")

    for ext, v in pairs(loaders) do
        local paths = { basename .. "." .. ext, basename .. "/init." .. ext }
        local found = get_user_runtime_file(table.concat(paths, " "), true, false, v.rtp)[1]
        if found then
            local luapath = compile(found)
            local f, err = loadfile(luapath)
            return f or error(err)
        end
    end
end

table.insert(package.loaders, loader)

function M.add_loader(ext, func, opts)
    opts = opts or {}
    local rtp = get_user_runtime_file((opts.dir or ext) .. "/", true, false)
    loaders[ext] = { func = func, opts = opts, rtp = rtp }
    setup_autocmds(ext)
    local plugins = get_user_runtime_file(string.format("plugin/**/*.%s", ext), true, vim.v.vim_did_enter == 1)
    for _, v in pairs(plugins) do
        source(v)
    end
end

_G.moonwalk = {
    source = source,
    handle_filetype = handle_filetype,
    load_after_plugins = load_after_plugins,
}

return M
