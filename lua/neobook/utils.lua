local M = {}

local function concat_tables (a, b)
	for i = 1, #b do
		a[#a + 1] = b[i]
	end
end

local function split (str, delimiter)
	local ret = {}

	for s in str:gmatch ('([^'.. delimiter .. ']+)') do
		table.insert (ret, s)
	end

	return ret
end

local function generate_cell_id ()
	local cell_id_format = {8, 4, 4, 4, 12}
	local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'

	local parts = {}

	for _, l in ipairs (cell_id_format) do
		local part = ''

		for _ = 1, l do
			local rand_idx = math.random (1, #chars)
			part = part .. chars:sub (rand_idx, rand_idx)
		end

		table.insert (parts, part)
	end

	return table.concat (parts, '-')

end


M.concat_tables = concat_tables
M.split = split
M.generate_cell_id = generate_cell_id

return M
