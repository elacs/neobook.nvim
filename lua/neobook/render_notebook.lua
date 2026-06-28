-- imports
local get_delimiters = require ('neobook.get_delimiters')

local image = require ('image')


local M = {}

local ns_id = vim.api.nvim_create_namespace ('neobook_cells')

local neobook_images = {}

local function concat_tables (a, b)
	for i = 1, #b do
		a[#a + 1] = b[i]
	end
end

local function render_image_at_current_line (image_path, line_number)

	print (image_path)

	local current_buf = vim.api.nvim_get_current_buf ()
	local current_win = vim.api.nvim_get_current_win ()

	local img = image.from_file (image_path, {
		id = image_path,
		window = current_win,
		buffer = current_buf,
		with_virtual_padding = true,
		inline = true,
		x = 0,
		y = line_number
	})

	if img then
		img:render ()

		neobook_images[current_buf] = neobook_images[current_buf] or {}
		table.insert (neobook_images[current_buf], img)
	end

	vim.api.nvim_create_autocmd ({'BufDelete', 'BufWipeout'}, {
		buffer = current_buf,
		callback = function ()
			neobook_images[current_buf] = nil
			os.remove (image_path)
		end,
		once = true
	})

end

local function notecell_to_displaycell (notecell)

	local is_code_cell = notecell.cell_type == 'code'

	local ret = {}
	local images_to_render = {}

	local exec_count = 0

	if is_code_cell then
		exec_count = (notecell.execution_count and notecell.execution_count ~= vim.NIL) and tostring (notecell.execution_count) or ''
	end

	local delimiters = get_delimiters.get_delimiters (is_code_cell, exec_count)

	table.insert (ret, delimiters.upper)

	if notecell.source then
		for _, line in ipairs (notecell.source) do
			table.insert (ret, (line:gsub ('\n$', '')))
		end
	end

	if notecell.outputs and #notecell.outputs > 0 then
		table.insert (ret, get_delimiters.output_delimiter)

		for _, output in ipairs (notecell.outputs) do
			if output.data and output.data['text/plain'] then
				for _, out_line in ipairs (output.data['text/plain']) do
					table.insert (ret, (out_line:gsub ('\n$', '')))
				end
			end

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

				-- local viu_cmd = string.format ("echo '%s' | base64 -d | viu -b -w 60 -", b64_data)
				--
				-- local image_text_lines = vim.fn.systemlist (viu_cmd)
				--
				-- for _, img_line in ipairs (image_text_lines) do
				-- 	table.insert (ret, img_line)
				-- end

			end

			if output.name == 'stdout' and output.text then
				for _, out_line in ipairs (output.text) do
					table.insert (ret, (out_line:gsub ('\n$', '')))
				end
			end

		end

	end

	table.insert (ret, delimiters.lower)

	return ret, images_to_render

end

local function render_notebook ()

	local lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)
	local content = table.concat (lines, '\n')

	local ok, parsed = pcall (vim.fn.json_decode, content)
	if not ok or type (parsed) ~= 'table' or not parsed.cells then
		-- print ('Error: Current buffer is not a valid Jupyter Notebook')
		return
	end

	vim.b.notebook_json = parsed
	local extmark_dict = {}

	vim.api.nvim_buf_set_lines (0, 0, -1, false, {})

	for _, cell in ipairs (parsed.cells) do

		local displaycell, images_to_render = notecell_to_displaycell (cell)

		local start_line = vim.api.nvim_buf_line_count (0)

		if start_line == 1 and vim.api.nvim_buf_get_lines (0, 0, 1, false) [1] == '' then
			start_line = 0
		end

		vim.api.nvim_buf_set_lines (0, start_line, -1, false, displaycell)

		for _, img_data in ipairs (images_to_render) do
			render_image_at_current_line (img_data.path, start_line + img_data.offset - 1)
		end

		local mark_id = vim.api.nvim_buf_set_extmark (0, ns_id, start_line, 0, {})

		extmark_dict[mark_id] = cell.id

	end

	vim.b.extmark_dict = extmark_dict

	vim.api.nvim_set_option_value ('filetype', 'python', { buf = 0 })

	local current_buf = vim.api.nvim_get_current_buf ()

	vim.api.nvim_clear_autocmds ({group = vim.api.nvim_create_augroup ('neobook_images_' .. current_buf, {clear = true}), buffer = current_buf})

	vim.api.nvim_create_autocmd ('BufWinEnter', {
		group = 'neobook_images_' .. current_buf,
		buffer = current_buf,
		callback = function ()
			if neobook_images[current_buf] then
				local new_win = vim.api.nvim_get_current_win ()
				for _, img in ipairs (neobook_images[current_buf]) do
					img.window = new_win
					img:render ()
				end
			end
		end
	})
end


M.render_notebook = render_notebook

return M
