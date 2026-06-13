return {
    'nvim-telescope/telescope-fzf-native.nvim',
    commit = 'b25b749',
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
}
