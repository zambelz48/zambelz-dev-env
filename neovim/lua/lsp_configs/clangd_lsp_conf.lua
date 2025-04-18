return {
    name = 'clangd',
    cmd = { 'clangd' },
    filetypes = {
        'c',
        'cpp',
        'cuda',
        'proto'
    },
    root_markers = { '.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json', 'compile_flags.txt', 'configure.ac', '.git' },
}
