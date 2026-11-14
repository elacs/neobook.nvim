-- imports
local utils = require ('neobook.utils')


local M = {}

local function initialize_notebook ()

	local notebook_template = {
		cells = {
			{
				cell_type = "code",
				execution_count = vim.NIL,
				id = utils.generate_cell_id (),
				metadata = vim.empty_dict (),
				outputs = {},
				source = {},
			}
		},
		metadata = {},
		nbformat = 4,
		nbformat_minor = 5
	}

	vim.b.notebook_json = notebook_template

end


M.initialize_notebook = initialize_notebook

return M
