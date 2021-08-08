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
will used the already compiled Lua function and will execute as fast as native
Lua.

## Configuration

The only requirement is a function that can transform a string of the source
language code into Lua. For example, with Fennel:

```lua
require("moonwalk").add_loader("fnl", function(src)
    return require("fennel").compileString(src)
end)
```

Once `add_loader` is called, any `*.fnl` files found under a `plugin` directory
on the user's `'runtimepath'` are sourced. You can also `require()` files found
under any `fnl` directories on your `'runtimepath'`.

This also works with `plugin` and `ftplugin` files. For example, you can
configure how Neovim works with C files by creating
`~/.config/nvim/after/ftplugin/c.fnl` with the contents:

```fennel
(set vim.bo.expandtab false)
(set vim.bo.shiftwidth 8)
```

So long as you can define a function that transforms the source into Lua, you
can use any source language you want, including custom DSLs!

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
[stub]: https://git.sr.ht/~gpanders/dotfiles/tree/6ba3d5e54b1b3ce4c6e74165bf51d8c832a1dd6d/item/.config/nvim/colors/base16-eighties.vim
[colors]: https://git.sr.ht/~gpanders/dotfiles/tree/6ba3d5e54b1b3ce4c6e74165bf51d8c832a1dd6d/item/.config/nvim/fnl/colors/base16-eighties.fnl

## Prior Art

* moonwalk is heavily inspired by [hotpot.nvim][]. Hotpot works only with
  Fennel but provides far more features than moonwalk.

[hotpot.nvim]: https://github.com/rktjmp/hotpot.nvim

## Contributing

File issues in the [GitHub issue tracker][issues]. Changes can be sent as
[`git-send-email`][git-send-email] patches to
[~gpanders/public-inbox@lists.sr.ht][public-inbox] or as a GitHub pull request.

[issues]: https://github.com/gpanders/nvim-moonwalk/issues
[git-send-email]: https://git-send-email.io
[public-inbox]: mailto:~gpanders/public-inbox@lists.sr.ht

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html)
