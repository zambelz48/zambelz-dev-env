return {
    'nvim-telescope/telescope-fzf-native.nvim',
    commit = '1f08ed6',
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
}
