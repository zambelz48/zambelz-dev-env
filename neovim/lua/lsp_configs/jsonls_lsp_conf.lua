local utils = require('utils')

local function get_json_schemas()
    if not utils.cache.json_schemas then
        -- Only compute this once and cache the result
        utils.cache.json_schemas = {
            {
                fileMatch = { "package.json" },
                url = "https://json.schemastore.org/package.json"
            },
            {
                fileMatch = { "tsconfig.json", "tsconfig.*.json" },
                url = "https://json.schemastore.org/tsconfig.json"
            },
            -- Add more schemas as needed
        }
    end
    return utils.cache.json_schemas
end

return {
    name = 'jsonls',
    cmd = { 'vscode-json-language-server', '--stdio' },
    filetypes = {
        'json',
        'jsonc'
    },
    init_options = {
        provideFormatter = true,
        schemas = get_json_schemas(),
    },
}
