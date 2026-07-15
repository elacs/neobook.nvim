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


M.concat_tables = concat_tables
M.split = split

return M
