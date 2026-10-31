import { readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const workspace = join(here, 'workspace');
const store = process.argv[2]
  || join(here, '..', '..', 'npm', 'node_modules', '.pnpm');
const entries = readdirSync(store);

function requireFrom(storePrefix, name) {
  const dir = entries.find((entry) => entry.startsWith(storePrefix));
  if (!dir) {
    throw new Error(`${storePrefix} is not installed`);
  }
  return createRequire(join(store, dir, 'node_modules', name, 'package.json'));
}

const checks = [
  ['bash-language-server: editorconfig with minimatch', async () => {
    const editorconfig = requireFrom('editorconfig@', 'editorconfig')(
      'editorconfig');
    const props = await editorconfig.parse(join(workspace, 'run.sh'));
    return props.indent_size === 2;
  }],
  ['bash-language-server: zod', () => {
    const { z } = requireFrom('bash-language-server@', 'bash-language-server')(
      'zod');
    return z.object({ a: z.number() }).parse({ a: 1 }).a === 1;
  }],
  ['graphql-language-service-server: glob', async () => {
    const { glob } = requireFrom('graphql-language-service-server@',
      'graphql-language-service-server')('glob');
    const files = await glob('**/*.graphql', {
      cwd: workspace,
      stat: true,
      withFileTypes: true,
      ignore: ['**/node_modules/**'],
    });
    const sync = glob.sync(join(workspace, '*.graphql'));
    return files.length === 2 && files.every((f) => f.size > 0)
      && sync.length === 2;
  }],
  ['graphql-config: minimatch and @graphql-tools/utils', async () => {
    const { loadConfig } = requireFrom('graphql-config@', 'graphql-config')(
      'graphql-config');
    const config = await loadConfig({ rootDir: workspace });
    const project = config.getProjectForFile(join(workspace, 'q.graphql'));
    const documents = await project.getDocuments();
    const schema = await project.getSchema();
    return documents.length === 1 && 'a' in schema.getQueryType().getFields();
  }],
  ['ansible-language-server: glob', async () => {
    const { glob } = requireFrom('@ansible+ansible-language-server@',
      '@ansible/ansible-language-server')('glob');
    const files = await glob('**/*.yml', { cwd: workspace });
    return files.includes('site.yml');
  }],
  ['prisma-language-server: deepmerge-ts', () => {
    const { deepmerge } = requireFrom('@prisma+language-server@',
      '@prisma/language-server')('deepmerge-ts');
    const merged = deepmerge({ a: { b: 1 } }, { a: { c: 2 } });
    return merged.a.b === 1 && merged.a.c === 2;
  }],
];

let failed = 0;
for (const [label, check] of checks) {
  try {
    if (await check()) {
      console.log(`OK: ${label}`);
    } else {
      failed += 1;
      console.log(`ERROR: ${label}: unexpected result`);
    }
  } catch (err) {
    failed += 1;
    console.log(`ERROR: ${label}: ${String(err).split('\n')[0]}`);
  }
}
process.exit(failed > 0 ? 1 : 0);
