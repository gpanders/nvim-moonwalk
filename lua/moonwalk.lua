local loaders = {}
local cachedir = vim.fn.stdpath("cache")
local function log(msg)
  local f = io.open((cachedir .. "/moonwalk.log"), "a")
  local function close_handlers_7_auto(ok_8_auto, ...)
    f:close()
    if ok_8_auto then
      return ...
    else
      return error(..., 0)
    end
  end
  local function _2_()
    f:write(("[%s] %s\n"):format(os.date("%F %T"), msg))
    return f:flush()
  end
  return close_handlers_7_auto(xpcall(_2_, (package.loaded.fennel or debug).traceback))
end
local function setup_autocmds(ext)
  return vim.cmd(("\naugroup moonwalk_%s\n    autocmd!\n    autocmd SourceCmd *.%s call v:lua.moonwalk.source(expand('<amatch>:p'))\n    autocmd FileType * ++nested call v:lua.moonwalk.handle_filetype('%s')\naugroup END"):format(ext, ext, ext))
end
local function compile(path)
  local ext = path:match("[^/.]%.(.-)$")
  local func = loaders[ext].func
  local luapath = (cachedir .. "/moonwalk" .. path:gsub(("%." .. ext .. "$"), ".lua"))
  local s = vim.loop.fs_stat(luapath)
  if (not s or (s.mtime.sec < vim.loop.fs_stat(path).mtime.sec)) then
    local input
    do
      local src = io.open(path, "r")
      local function close_handlers_7_auto(ok_8_auto, ...)
        src:close()
        if ok_8_auto then
          return ...
        else
          return error(..., 0)
        end
      end
      local function _4_()
        return src:read("*a")
      end
      input = close_handlers_7_auto(xpcall(_4_, (package.loaded.fennel or debug).traceback))
    end
    local _5_, _6_ = pcall(func, input, path)
    if ((_5_ == true) and (nil ~= _6_)) then
      local output = _6_
      vim.fn.mkdir(luapath:match("(.+)/.-%.lua"), "p")
      do
        local dst = io.open(luapath, "w")
        local function close_handlers_7_auto(ok_8_auto, ...)
          dst:close()
          if ok_8_auto then
            return ...
          else
            return error(..., 0)
          end
        end
        local function _8_()
          return dst:write(output)
        end
        close_handlers_7_auto(xpcall(_8_, (package.loaded.fennel or debug).traceback))
      end
      log(("Compiled %s to %s"):format(path, luapath))
    elseif ((_5_ == false) and (nil ~= _6_)) then
      local err = _6_
      log(err)
      error(err, 0)
    end
  end
  return luapath
end
local function get_user_runtime_file(name, after, all)
  local t = {vim.fn.stdpath("config"), (vim.fn.stdpath("data") .. "/site")}
  local rtp = vim.o.runtimepath
  local pp = vim.o.packpath
  if after then
    for i = 1, #t do
      table.insert(t, (t[i] .. "/after"))
    end
  end
  vim.o.runtimepath = table.concat(t, ",")
  vim.o.packpath = ""
  local found = vim.api.nvim_get_runtime_file(name, all)
  vim.o.runtimepath = rtp
  vim.o.packpath = pp
  return found
end
local function source(path)
  local ext = path:match("[^/.]%.(.-)$")
  local _12_, _13_ = pcall(compile, path)
  if ((_12_ == true) and (nil ~= _13_)) then
    local luafile = _13_
    return vim.api.nvim_command(("source " .. luafile))
  elseif ((_12_ == false) and (nil ~= _13_)) then
    local err = _13_
    return vim.notify(err, vim.log.levels.ERROR)
  end
end
local function load_after_plugins()
  for ext in pairs(loaders) do
    local pat = ("after/plugin/**/*.%s"):format(ext)
    for _, plugin in pairs(get_user_runtime_file(pat, false, true)) do
      source(plugin)
    end
  end
  return nil
end
local function handle_filetype(ext)
  local s = vim.fn.expand("<amatch>")
  for name in vim.gsplit((s or ""), ".", true) do
    if name then
      local pat = ("ftplugin/%s.%s ftplugin/%s_*.%s ftplugin/%s/*.%s indent/%s.%s"):format(name, ext, name, ext, name, ext, name, ext)
      for _, file in pairs(get_user_runtime_file(pat, true, true)) do
        source(file)
      end
    end
  end
  return nil
end
local function loader(name)
  local basename = name:gsub("%.", "/")
  local luapath = nil
  for ext, v in pairs(loaders) do
    if luapath then break end
    local opts = (v.opts or {})
    local dir = (opts.dir or ext)
    local paths = {(dir .. "/" .. basename .. "." .. ext), (dir .. "/" .. basename .. "/init." .. ext)}
    local found = (get_user_runtime_file(table.concat(paths, " "), true, false))[1]
    if found then
      luapath = compile(found)
    end
  end
  if luapath then
    local f, err = loadfile(luapath)
    return (f or error(err))
  end
end
local function add_loader(ext, func, opts)
  loaders[ext] = {func = func, opts = opts}
  setup_autocmds(ext)
  local pat = ("plugin/**/*.%s"):format(ext)
  for _, plugin in pairs(get_user_runtime_file(pat, (vim.v.vim_did_enter == 1), true)) do
    source(plugin)
  end
  return nil
end
moonwalk = {handle_filetype = handle_filetype, load_after_plugins = load_after_plugins, source = source}
table.insert(package.loaders, loader)
return {add_loader = add_loader}
