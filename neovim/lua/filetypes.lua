-- Compound filetypes expected by docker_compose_language_service and
-- ansiblels; Neovim detects these files as plain `yaml`.
vim.filetype.add({
  pattern = {
    ['.*/docker%-compose%.ya?ml'] = 'yaml.docker-compose',
    ['.*/docker%-compose%.[^/]+%.ya?ml'] = 'yaml.docker-compose',
    ['.*/compose%.ya?ml'] = 'yaml.docker-compose',
    ['.*/compose%.[^/]+%.ya?ml'] = 'yaml.docker-compose',
    ['.*/roles/[^/]+/tasks/[^/]+%.ya?ml'] = 'yaml.ansible',
    ['.*/roles/[^/]+/handlers/[^/]+%.ya?ml'] = 'yaml.ansible',
    ['.*/playbooks/[^/]+%.ya?ml'] = 'yaml.ansible',
  },
})

vim.treesitter.language.register('yaml', {
  'yaml.docker-compose',
  'yaml.ansible',
})
