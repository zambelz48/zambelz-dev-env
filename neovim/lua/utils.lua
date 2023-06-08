local Mod = {}

function Mod.nnoremap(lhs, rhs, opts)
	local options = { noremap = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.api.nvim_set_keymap('n', lhs, rhs, options)
end

function Mod.tnoremap_buf(lhs, rhs, opts)
	local options = { noremap = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.api.nvim_buf_set_keymap(0, 't', lhs, rhs, options)
end

function Mod.shell_cmd(cmd)
	local handle = assert(io.popen(cmd, 'r'))
	local output = assert(handle:read('*a'))
	handle:close()

	output = string.gsub(
		string.gsub(
			string.gsub(output, '^%s+', ''),
			'%s+$',
			''
		),
		'[\n\r]+',
		' '
	)

	return output
end

return Mod
