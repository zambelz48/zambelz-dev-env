local nvim_lsp = require 'lspconfig'

return {
    name = 'tailwindcss',
    cmd = { 'tailwindcss-language-server', '--stdio' },
    filetypes = {
        'aspnetcorerazor', 'astro', 'astro-markdown', 'blade', 'clojure',
        'django-html', 'htmldjango', 'edge', 'eelixir', 'elixir', 'ejs',
        'erb', 'eruby', 'gohtml', 'haml', 'handlebars', 'hbs', 'html',
        'html-eex', 'heex', 'jade', 'leaf', 'liquid', 'markdown', 'mdx',
        'mustache', 'njk', 'nunjucks', 'php', 'razor', 'slim', 'twig',
        'css', 'less', 'postcss', 'sass', 'scss', 'stylus', 'sugarss',
        'javascript', 'javascriptreact', 'reason', 'rescript', 'typescript',
        'typescriptreact', 'vue', 'svelte'
    },
    settings = {
        taildwindCSS = {
            classAttributes = { 'class', 'className', 'class:list', 'classList', 'ngClass' },
            lint = {
                cssConflict = 'warning',
                invalidApply = 'error',
                invalidConfigPath = 'error',
                invalidScreen = 'error',
                invalidTailwindDirective = 'error',
                invalidVariant = 'error',
                recommendedVariantOrder = 'warning'
            },
            validate = true
        }
    },
    root_dir = nvim_lsp.util.root_pattern(
        'tailwind.config.js', 'tailwind.config.cjs', 'tailwind.config.mjs',
        'tailwind.config.ts', 'postcss.config.js', 'postcss.config.cjs',
        'postcss.config.mjs', 'postcss.config.ts', 'package.json',
        'node_modules', '.git'
    )
}
