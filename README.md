# moonwalk

moonwalk allows you to use any language that compiles to Lua anywhere in your
Neovim configuration.

## Demo

**init.lua**:

```lua
require("moonwalk").add_loader("fnl", function(src)
    return require("fennel").compileString(src)
end)
```

**fnl/hello.fnl**:

```fennel
(print "Hello world")
```

Open Neovim and run `:lua require("hello")`.

**after/ftplugin/lua.fnl**:

```fennel
(set vim.bo.expandtab true)
(set vim.bo.shiftwidth 17)
```

Open `init.lua` in Neovim and confirm that `:set expandtab?` shows `true` and
`:set shiftwidth?` shows `17`.

## How does it work?

moonwalk inserts a shim into the Lua package loader that transparently compiles
source files into Lua. The compilation is cached and will not be repeated
unless the source file changes.

This means that the cost of compilation is only paid once: future invocations
will execute as fast as native Lua.

moonwalk intercepts `:source` and `:runtime` commands for files with the
extensions you provide. This allows you to use any language anywhere you can
use a `.vim` or `.lua` file natively (with a couple of exceptions, see
[caveats](#caveats)) such as `plugin`, `ftplugin`, or `indent` files.

## Configuration

The only requirement is a function that can transform a string of the source
language code into Lua. For example, with Fennel:

```lua
require("moonwalk").add_loader("fnl", function(src, path)
    return require("fennel").compileString(src, { filename = path })
end)
```

The provided function can also take an optional second parameter `path` with
the full path of the file being compiled.

Once `add_loader` is called, any files with the extension provided found under
a `plugin` directory on the user's `'runtimepath'` are sourced. You can also
`require()` files found under any `{ext}` directories on your `'runtimepath'`,
where `{ext}` is the first argument to `add_loader`. For example, if you add a
loader for Teal with `add_loader("tl", function(src) ... end)` you can
`require()` any `*.tl` files within a `tl` directory on your `'runtimepath'`
(just as you can `require()` `*.lua` files within a `lua` directory).

This also works with `plugin` and `ftplugin` files. For example, you can
configure how Neovim works with C files by creating
`~/.config/nvim/after/ftplugin/c.fnl` with the contents:

```fennel
(set vim.bo.expandtab false)
(set vim.bo.shiftwidth 8)
```

The examples above use Fennel, but so long as you can define a function that
transforms the source into Lua, you can use any source language you want,
including custom DSLs!

### Options

The `add_loader` function takes an optional table as its third argument with
the following keys:

* `dir`: Directory to use in the `'runtimepath'` to find modules for this
  loader (for example, Lua modules are found under the `lua` directory). The
  default is the extension passed as the first argument to `add_loader`, e.g.
  if the file extension is "tl" then script files will be searched for under
  the `tl` directory.

## Caveats

* moonwalk is minimal by design: the only thing it provides is the shim
  infrastructure. Users must provide their transformation functions themselves
  (see the [wiki][wiki] for some user-contributed examples).

* The `:colorscheme` command won't work natively with alternative languages,
  since it does not go through the `SourceCmd` autocommand. There are a couple
  of ways to get around this:

  1. If you are already using an `init.lua` file, you can simply write your
     colorscheme file as a script and then `require()` it rather than using the
     `:colorscheme` command.
  2. If you are using an `init.vim` file you can create a stub colorscheme file
     that `require()`s your actual colorscheme file. See an example
     here: [stub][], [colors][].

[wiki]: https://github.com/gpanders/nvim-moonwalk/wiki
[stub]: https://github.com/gpanders/dotfiles/blob/6ba3d5e54b1b3ce4c6e74165bf51d8c832a1dd6d/.config/nvim/colors/base16-eighties.vim
[colors]: https://github.com/gpanders/dotfiles/blob/6ba3d5e54b1b3ce4c6e74165bf51d8c832a1dd6d/.config/nvim/fnl/colors/base16-eighties.fnl

## Examples

The examples below are all written in Fennel. If you've used moonwalk in a
language other than Fennel and you'd like to share your own examples, please
let me know and I will add them here.

* [Moonwalk configuration][config]
* [Useful macros][macros]
* Plugin configuration: [lspconfig][], [telescope][], [compe][], [nvim-lint][]
* ftplugins: [C][c ftplugin], [Fennel][fennel ftplugin]
* [Asynchronous grep wrapper][grep]

[config]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/plugin/moonwalk.lua
[macros]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/fnl/macros.fnl
[lspconfig]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/plugin/lspconfig.fnl
[telescope]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/plugin/telescope.fnl
[compe]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/plugin/compe.fnl
[nvim-lint]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/plugin/lint.fnl
[c ftplugin]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/after/ftplugin/c.fnl
[fennel ftplugin]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/after/ftplugin/fennel.fnl
[grep]: https://github.com/gpanders/dotfiles/blob/master/.config/nvim/plugin/grep.fnl

## FAQ

### Why is this useful?

It's not, but it's fun.

### What is the performance impact?

Short answer: marginal.

Long answer:

Compiling languages into Lua takes a non-trivial amount of time, but this is
only done once so you shouldn't worry about it. Once the source file is
compiled it is cached until the source file changes again. Future invocations
are (nearly) as fast as using Lua directly.

It is only *nearly* as fast because the custom loader that moonwalk inserts is
at the end of Lua's `package.loaders` table. This means that when you
`require()` a module written in an extension language Lua has to iterate
through the other package loaders first before it finally gets to moonwalk.
moonwalk also has to do a few things in order to determine whether or not the
source file has changed such as checking file modification times. However, this
process takes on the order of microseconds, so don't sweat it too much.

The other performance impact comes from searching for runtime files in the
given extension language. On startup, moonwalk runs (essentially) the following
command:

```vim
:runtime! plugin/**/*.{ext}
```

where `{ext}` is the provided extension (e.g. `moon`, `tl`, etc.). Searching
through the runtime path recursively takes a few milliseconds, so if you are a
startuptime junkie you may notice this. moonwalk takes measures to speed up
this process as much as possible, but there is a ceiling on how fast this can
be done.

## Prior Art

* moonwalk is heavily inspired by [hotpot.nvim][]. Hotpot works only with
  Fennel but provides far more features than moonwalk.
* [aniseed][] is another plugin that provides Fennel support for Neovim, along
  with an entire standard library and utility functions.

[hotpot.nvim]: https://github.com/rktjmp/hotpot.nvim
[aniseed]: https://github.com/Olical/aniseed

## Contributing

If you extend Neovim with an extension language other than Fennel, please let
me know so I can include some of those entries in the [examples](#examples).

The wiki is publicy editable. If you think you have a useful contribution,
please share it!

File issues in the [GitHub issue tracker][issues]. Changes can be sent as
[`git-send-email`][git-send-email] patches to
[~gpanders/public-inbox@lists.sr.ht][public-inbox] or as a GitHub pull request.

[issues]: https://github.com/gpanders/nvim-moonwalk/issues
[git-send-email]: https://git-send-email.io
[public-inbox]: mailto:~gpanders/public-inbox@lists.sr.ht

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html)
