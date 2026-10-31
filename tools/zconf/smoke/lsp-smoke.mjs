import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const workspace = join(dirname(fileURLToPath(import.meta.url)), 'workspace');
const servers = [
  ['ansiblels', ['ansible-language-server', '--stdio'], 'ansible', 'site.yml'],
  ['bashls', ['bash-language-server', 'start'], 'sh', 'run.sh'],
  ['cssls', ['vscode-css-language-server', '--stdio'], 'css', 'a.css'],
  ['docker_compose_language_service',
    ['docker-compose-langserver', '--stdio'], 'yaml', 'compose.yaml'],
  ['dockerls', ['docker-langserver', '--stdio'], 'dockerfile', 'Dockerfile'],
  ['eslint', ['vscode-eslint-language-server', '--stdio'], 'javascript',
    'a.js'],
  ['graphql', ['graphql-lsp', 'server', '-m', 'stream'], 'graphql',
    'q.graphql'],
  ['html', ['vscode-html-language-server', '--stdio'], 'html', 'a.html'],
  ['jsonls', ['vscode-json-language-server', '--stdio'], 'json', 'a.json'],
  ['prismals', ['prisma-language-server', '--stdio'], 'prisma',
    'schema.prisma'],
  ['tailwindcss', ['tailwindcss-language-server', '--stdio'], 'html',
    'a.html'],
  ['tsc', ['tsc', '--lsp', '--stdio'], 'typescript', 'a.ts'],
  ['vimls', ['vim-language-server', '--stdio'], 'vim', 'a.vim'],
  ['yamlls', ['yaml-language-server', '--stdio'], 'yaml', 'compose.yaml'],
];
const failure =
  /TypeError|ReferenceError|is not a function|Cannot find module|Unhandled/;
const METHOD_NOT_FOUND = -32601;

function frame(message) {
  const body = JSON.stringify({ jsonrpc: '2.0', ...message });
  return `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`;
}

function reply(message) {
  if (message.method === 'workspace/configuration') {
    return (message.params.items || []).map(() => ({}));
  }
  return null;
}

function run([name, command, languageId, file]) {
  return new Promise((resolve) => {
    const child = spawn(command[0], command.slice(1), { cwd: workspace });
    const pending = new Map();
    const errors = [];
    let buffer = Buffer.alloc(0);
    let nextId = 0;
    let exited = null;
    const send = (message) => child.stdin.write(frame(message));
    const request = (method, params) => new Promise((done) => {
      nextId += 1;
      pending.set(nextId, done);
      if (params === undefined) {
        send({ id: nextId, method });
      } else {
        send({ id: nextId, method, params });
      }
    });
    const handle = (message) => {
      if (message.id !== undefined && message.method) {
        send({ id: message.id, result: reply(message) });
      } else if (message.id !== undefined && pending.has(message.id)) {
        pending.get(message.id)(message);
        pending.delete(message.id);
      } else if (message.method === 'window/logMessage'
        && failure.test(message.params.message)) {
        errors.push(message.params.message);
      }
    };
    child.stdout.on('data', (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      for (;;) {
        const end = buffer.indexOf('\r\n\r\n');
        if (end < 0) {
          return;
        }
        const length = Number(/Content-Length: (\d+)/i
          .exec(buffer.subarray(0, end).toString())[1]);
        if (buffer.length < end + 4 + length) {
          return;
        }
        handle(JSON.parse(buffer.subarray(end + 4, end + 4 + length)));
        buffer = buffer.subarray(end + 4 + length);
      }
    });
    child.stderr.on('data', (chunk) => {
      for (const line of chunk.toString().split('\n')) {
        if (failure.test(line)) {
          errors.push(line);
        }
      }
    });
    child.on('exit', (code, signal) => {
      exited = { code, signal };
      for (const done of pending.values()) {
        done({ error: { message: `server exited: ${code ?? signal}` } });
      }
      pending.clear();
    });
    child.on('error', (err) => resolve({ name, problem: err.message }));
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      resolve({ name, problem: 'no answer within 60s' });
    }, 60000);
    const finish = (problem) => {
      clearTimeout(timer);
      child.kill('SIGKILL');
      resolve({ name, problem, errors });
    };
    (async () => {
      const root = pathToFileURL(workspace).href;
      const init = await request('initialize', {
        processId: process.pid,
        rootUri: root,
        workspaceFolders: [{ uri: root, name: 'workspace' }],
        capabilities: {
          workspace: { workspaceFolders: true, configuration: true },
          textDocument: {
            hover: { contentFormat: ['markdown', 'plaintext'] },
            synchronization: { didSave: true },
          },
        },
      });
      if (init.error) {
        finish(`initialize failed: ${JSON.stringify(init.error)}`);
        return;
      }
      send({ method: 'initialized', params: {} });
      const uri = pathToFileURL(join(workspace, file)).href;
      send({
        method: 'textDocument/didOpen',
        params: {
          textDocument: {
            uri,
            languageId,
            version: 1,
            text: readFileSync(join(workspace, file), 'utf8'),
          },
        },
      });
      await new Promise((done) => setTimeout(done, 4000));
      const position = {
        textDocument: { uri },
        position: { line: 1, character: 2 },
      };
      const answers = [
        ['hover', await request('textDocument/hover', position)],
        ['completion', await request('textDocument/completion', position)],
      ];
      await new Promise((done) => setTimeout(done, 2000));
      if (exited !== null) {
        finish(`exited early: ${JSON.stringify(exited)}`);
        return;
      }
      await request('shutdown');
      send({ method: 'exit' });
      const failed = answers.find(([, answer]) => answer.error
        && answer.error.code !== METHOD_NOT_FOUND);
      if (failed) {
        finish(`${failed[0]} failed: ${JSON.stringify(failed[1].error)}`);
        return;
      }
      finish('');
    })();
  });
}

const only = process.argv.slice(2);
let failed = 0;
for (const server of servers) {
  if (only.length > 0 && !only.includes(server[0])) {
    continue;
  }
  const { name, problem, errors = [] } = await run(server);
  if (problem || errors.length > 0) {
    failed += 1;
    console.log(`ERROR: ${name}${problem ? `: ${problem}` : ''}`);
    for (const line of errors.slice(0, 5)) {
      console.log(`  ${line.split('\n')[0].slice(0, 200)}`);
    }
  } else {
    console.log(`OK: ${name}`);
  }
}
process.exit(failed > 0 ? 1 : 0);
