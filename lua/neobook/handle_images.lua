local image = require ('image')


local M = {}

local neobook_images_dict = {}

local function render_image_at_current_line (image_path, line_number)

	-- print (image_path)

	local current_buf = vim.api.nvim_get_current_buf ()
	local current_win = vim.api.nvim_get_current_win ()

	local neobook_images = neobook_images_dict[current_buf] or {}

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

		table.insert (neobook_images, {
			img = img,
			img_path = image_path
		})
	end

	neobook_images_dict[current_buf] = neobook_images

end

local function clear_images (buf_id)

	buf_id = buf_id or vim.api.nvim_get_current_buf ()

	local neobook_images = neobook_images_dict[buf_id]
	if not neobook_images or #neobook_images == 0 then return end

	for _, img_info in ipairs (neobook_images) do
		img_info.img:clear ()
		os.remove (img_info.img_path)
	end

	neobook_images_dict[buf_id] = {}
end

local function register_image_autocommands ()
	local current_buf = vim.api.nvim_get_current_buf ()

	vim.api.nvim_clear_autocmds ({ group = vim.api.nvim_create_augroup ('neobook_images_' .. current_buf, { clear = true }), buffer = current_buf })

	vim.api.nvim_create_autocmd ('BufWinEnter', {
		group = 'neobook_images_' .. current_buf,
		buffer = current_buf,
		callback = function ()
			local neobook_images = neobook_images_dict[current_buf]

			if neobook_images and #neobook_images ~= 0 then
				local new_win = vim.api.nvim_get_current_win ()
				for _, img_info in ipairs (neobook_images) do
					img_info.img.window = new_win
					img_info.img:render ()
				end
			end
		end
	})

	vim.api.nvim_create_autocmd ({'BufDelete', 'BufWipeout'}, {
		group = 'neobook_images_' .. current_buf,
		buffer = current_buf,
		callback = function (args) clear_images (args.buf) end,
		once = true
	})

end


M.render_image_at_current_line = render_image_at_current_line
M.register_image_autocommands = register_image_autocommands
M.clear_images = clear_images

return M
