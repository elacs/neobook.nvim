# neobook.nvim
nvim plugin for rendering (and running) jupyter notebooks

## dependencies

###	jupyter kernel

`neobook.nvim` relies on a background Jupyter kernel server and conversion utilities. Ensure you have the following packages installed in your environment:

```bash
# Required for kernel execution
pip install jupyter_client

# Required for exporting notebooks
pip install nbconvert

# Optional: Required if you intend to export directly to PDF
# A system TeX distribution (e.g., texlive-full, MacTeX, or MiKTeX) and pandoc
```

### image rendering

Because `neobook.nvim` uses [`image.nvim`](https://github.com/3rd/image.nvim) to render inline plots and graphics directly inside your Neovim buffer, ensure your system meets its requirements


## installation

You can install `neobook.nvim` using your favorite plugin manager. Here is the configuration for [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
	'elacs/neobook.nvim',
	ft = { "ipynb" },
	dependencies = {
		'3rd/image.nvim'
	},
	config = function()
		require('neobook').setup()
	end
}
```

## todo
- more output rendering cases probably
- rendering md?
- virtual line outputs?
