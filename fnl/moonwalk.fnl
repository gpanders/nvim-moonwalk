; Copyright (C) 2021 Gregory Anders
;
; SPDX-License-Identifier: GPL-3.0-or-later
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(local loaders {})
(local cachedir (vim.fn.stdpath :cache))

(fn log [msg]
  (with-open [f (io.open (.. cachedir "/moonwalk.log") :a)]
    (f:write (: "[%s] %s\n" :format (os.date "%F %T") msg))
    (f:flush)))

(macro extension [path]
  `(: ,path :match "[^/.]%.(.-)$"))

; TODO: Rewrite this when autocommands are supported natively in Lua
(fn setup-autocmds [ext]
  (vim.cmd (: "
augroup moonwalk_%s
    autocmd!
    autocmd SourceCmd *.%s call v:lua.moonwalk.source(expand('<amatch>:p'))
    autocmd FileType * ++nested call v:lua.moonwalk.handle_filetype('%s')
augroup END"
    :format ext ext ext)))

(fn compile [path]
  (let [ext (extension path)
        func (. loaders ext :func)
        luapath (.. cachedir "/moonwalk" (path:gsub (.. "%." ext "$") ".lua"))
        s (vim.loop.fs_stat luapath)]
    (when (or (not s) (< s.mtime.sec (. (vim.loop.fs_stat path) :mtime :sec)))
      (let [input (with-open [src (io.open path :r)]
                    (src:read "*a"))]
        (match (pcall func input path)
          (true output)
            (do
              (vim.fn.mkdir (luapath:match "(.+)/.-%.lua") :p)
              (with-open [dst (io.open luapath :w)]
                (dst:write output))
              (log (: "Compiled %s to %s" :format path luapath)))
          (false err)
            (do
              (log err)
              (error err 0)))))
    luapath))

(fn get-user-runtime-file [name after all]
  (let [t [(vim.fn.stdpath :config) (.. (vim.fn.stdpath :data) "/site")]
        rtp vim.o.runtimepath
        pp vim.o.packpath]
    (when after
      (for [i 1 (length t)]
        (table.insert t (.. (. t i) "/after"))))
    (set vim.o.runtimepath (table.concat t ","))
    (set vim.o.packpath "")
    (let [found (vim.api.nvim_get_runtime_file name all)]
      (set vim.o.runtimepath rtp)
      (set vim.o.packpath pp)
      found)))

(fn source [path]
  (let [ext (extension path)]
    (match (pcall compile path)
      (true luafile) (vim.api.nvim_command (.. "source " luafile))
      (false err) (vim.notify err vim.log.levels.ERROR))))

(fn load-after-plugins []
  (each [ext (pairs loaders)]
    (let [pat (: "after/plugin/**/*.%s" :format ext)]
    (each [_ plugin (pairs (get-user-runtime-file pat false true))]
      (source plugin)))))

(fn handle-filetype [ext]
  (let [s (vim.fn.expand "<amatch>")]
    (each [name (vim.gsplit (or s "") "." true)]
      (when name
        (let [pat (: "ftplugin/%s.%s ftplugin/%s_*.%s ftplugin/%s/*.%s indent/%s.%s" :format name ext name ext name ext name ext)]
          (each [_ file (pairs (get-user-runtime-file pat true true))]
            (source file)))))))

(fn loader [name]
  (let [basename (name:gsub "%." "/")]
    (var luapath nil)
    (each [ext v (pairs loaders) :until luapath]
      (let [opts (or v.opts {})
            dir (or opts.dir ext)
            paths [(.. dir "/" basename "." ext) (.. dir "/" basename "/init." ext)]
            found (. (get-user-runtime-file (table.concat paths " ") true false) 1)]
        (when found
          (set luapath (compile found)))))
    (when luapath
      (let [(f err) (loadfile luapath)]
        (or f (error err))))))

(fn add-loader [ext func opts]
  (tset loaders ext {: func : opts})
  (setup-autocmds ext)
  (let [pat (: "plugin/**/*.%s" :format ext)]
    (each [_ plugin (pairs (get-user-runtime-file pat (= vim.v.vim_did_enter 1) true))]
      (source plugin))))

(global moonwalk {: source :handle_filetype handle-filetype :load_after_plugins load-after-plugins})

(table.insert package.loaders loader)

{:add_loader add-loader}
