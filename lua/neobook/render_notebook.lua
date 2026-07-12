-- imports
local handle_delimiters = require ('neobook.handle_delimiters')
local handle_images = require ('neobook.handle_images')


local M = {}

local cell_id_ns = vim.api.nvim_create_namespace ('neobook_cell_ids')
local delimiter_ns = vim.api.nvim_create_namespace ('neobook_delimiters')

local function concat_tables (a, b)
	for i = 1, #b do
		a[#a + 1] = b[i]
	end
end

local function handle_output (output, ret, images_to_render)
	if output.data then
		if output.data['text/plain'] then
			for _, out_line in ipairs (output.data['text/plain']) do
				table.insert (ret, (out_line:gsub ('\n$', '')))
			end
		end

		if output.data['image/png'] then
			local b64_data = output.data['image/png']

			if type (b64_data) == 'table' then b64_data = table.concat (b64_data) end

			b64_data = b64_data:gsub ('\n', '')

			local binary_data = vim.base64.decode (b64_data)

			local temp_path = vim.fn.tempname () .. '.png'
			local f = io.open (temp_path, 'wb')

			if f then
				f:write (binary_data)
				f:close ()

				table.insert (images_to_render, {
					path = temp_path,
					offset = #ret
				})

			end
		end

	end

	if output.name == 'stdout' and output.text then
		for _, out_line in ipairs (output.text) do
			table.insert (ret, (out_line:gsub ('\n$', '')))
		end
	end

end

local function handle_output_2 (output, ret, images_to_render)
	local cases = {
		['stream'] = function ()
			if output.name == 'stdout' and output.text then
				for _, out_line in ipairs (output.text) do
					table.insert (ret, (out_line:gsub ('\n$', '')))
				end
			end
		end,
		['execute_result'] = function ()
			if output.data and output.data['text/plain'] then
				for _, out_line in ipairs (output.data['text/plain']) do
					table.insert (ret, (out_line:gsub ('\n$', '')))
				end
			end
		end,
		['display_data'] = function ()
			if output.data and output.data['image/png'] then
				local b64_data = output.data['image/png']

				if type (b64_data) == 'table' then b64_data = table.concat (b64_data) end

				b64_data = b64_data:gsub ('\n', '')

				local binary_data = vim.base64.decode (b64_data)

				local temp_path = vim.fn.tempname () .. '.png'
				local f = io.open (temp_path, 'wb')

				if f then
					f:write (binary_data)
					f:close ()

					table.insert (images_to_render, {
						path = temp_path,
						offset = #ret
					})

				end

			end

		end,
		['error'] = function () end
	}

	cases[output.output_type] ()

end

local function notecell_to_displaycell (notecell)

	local is_code_cell = notecell.cell_type == 'code'

	local ret = {}
	local images_to_render = {}

	local exec_count = ''

	if is_code_cell then
		exec_count = (notecell.execution_count and notecell.execution_count ~= vim.NIL) and tostring (notecell.execution_count) or ''
	end

	if notecell.source then

		if #notecell.source == 0 then
			table.insert (ret, '')
		else
			for i, line in ipairs (notecell.source) do

				local gsubbed_line, count = line:gsub ('\n$', '')

				table.insert (ret, gsubbed_line)

				if i == #notecell.source and count ~= 0 then
					table.insert (ret, '')
				end
			end
		end

		-- table.insert (ret, '')
	end

	local output_offset = -1

	if notecell.outputs and #notecell.outputs > 0 then
		output_offset = #ret + 1

		for _, output in ipairs (notecell.outputs) do
			handle_output (output, ret, images_to_render)
		end

	end

	return ret, images_to_render, is_code_cell, output_offset, exec_count

end

local function load_file_to_notebook_json ()
	local lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)
	local content = table.concat (lines, '\n')

	local ok, parsed = pcall (vim.fn.json_decode, content)
	if not ok or type (parsed) ~= 'table' or not parsed.cells then
		-- print ('Error: Current buffer is not a valid Jupyter Notebook')
		return
	end

	vim.b.notebook_json = parsed

end

local function register_extmarks (cell_id_info_lis, delimiters_info_lis)
	local cell_id_extmark_dict = {}

	for _, cell_id_info in ipairs (cell_id_info_lis) do
		local mark_id = vim.api.nvim_buf_set_extmark (0, cell_id_ns, cell_id_info.line_num, 0, {
			right_gravity = false
		})

		cell_id_extmark_dict[mark_id] = cell_id_info.cell_id
	end

	vim.b.cell_id_extmark_dict = cell_id_extmark_dict

	handle_delimiters.register_delimiter_extmarks (delimiters_info_lis)
end

local function clear_extmarks ()
	vim.b.cell_id_extmark_dict = {}
	vim.b.delimiter_extmark_dict = {}

	vim.api.nvim_buf_clear_namespace (0, cell_id_ns, 0, -1)
	vim.api.nvim_buf_clear_namespace (0, delimiter_ns, 0, -1)
end

local function render_notebook_from_notebook_json ()
	handle_images.clear_images ()

	local notebook_json = vim.b.notebook_json

	-- local cell_id_extmark_dict = {}
	local cell_id_info_lis = {}
	local delimiters_info_lis = {}

	vim.api.nvim_buf_set_lines (0, 0, -1, false, {})

	for _, cell in ipairs (notebook_json.cells) do

		local displaycell, images_to_render, is_code_cell, output_offset, exec_count = notecell_to_displaycell (cell)

		local start_line = vim.api.nvim_buf_line_count (0)

		if start_line == 1 and vim.api.nvim_buf_get_lines (0, 0, 1, false) [1] == '' then
			start_line = 0
		end

		vim.api.nvim_buf_set_lines (0, start_line, -1, false, displaycell)

		for _, img_data in ipairs (images_to_render) do
			handle_images.render_image_at_current_line (img_data.path, start_line + img_data.offset - 1)
		end

		-- local mark_id = vim.api.nvim_buf_set_extmark (0, cell_id_ns, start_line, 0, {
		-- 	right_gravity = false
		-- })
		--
		-- cell_id_extmark_dict[mark_id] = cell.id
		table.insert (cell_id_info_lis, {
			line_num = start_line,
			cell_id = cell.id
		})

		table.insert (delimiters_info_lis, {
			line_num = start_line,
			delimiter_type = 0, -- 0: first line, 1: last line, 2: first line of output
			is_code_cell = is_code_cell,
			exec_count = exec_count
		})

		table.insert (delimiters_info_lis, {
			line_num = start_line + #displaycell,
			delimiter_type = 1,
			is_code_cell = is_code_cell,
			exec_count = exec_count
		})

		if output_offset ~= -1 then
			table.insert (delimiters_info_lis, {
				line_num = start_line + output_offset - 1,
				delimiter_type = 2,
				is_code_cell = is_code_cell,
				exec_count = exec_count

			})
		end

	end

	-- vim.b.cell_id_extmark_dict = cell_id_extmark_dict

	-- handle_delimiters.register_delimiter_extmarks (delimiters_info_lis)

	vim.api.nvim_set_option_value ('filetype', 'python', { buf = 0 })

	handle_images.register_image_autocommands ()

	-- return cell_id_info_lis, delimiters_info_lis
	clear_extmarks ()
	register_extmarks (cell_id_info_lis, delimiters_info_lis)
end

local function render_notebook ()

	load_file_to_notebook_json ()
	-- local cell_id_info_lis, delimiters_info_lis = render_notebook_from_notebook_json ()
	-- register_extmarks (cell_id_info_lis, delimiters_info_lis)
	render_notebook_from_notebook_json ()
end


M.render_notebook = render_notebook
M.render_notebook_from_notebook_json = render_notebook_from_notebook_json

return M
