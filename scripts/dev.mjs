import { spawn } from 'node:child_process';
import { readdirSync, statSync, watch } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve('.');

const runBuildPages = () =>
  new Promise((resolveBuild, rejectBuild) => {
    const child = spawn('node', ['./scripts/render-partials.mjs'], {
      cwd: root,
      stdio: 'inherit',
    });

    child.on('exit', (code) => {
      if (code === 0) {
        resolveBuild();
        return;
      }

      rejectBuild(new Error(`render-partials exited with code ${code}`));
    });
  });

const startTailwindWatch = () =>
  spawn(
    'npx',
    ['tailwindcss', '-i', './src/input.css', '-o', './public/css/style.css', '--watch'],
    {
      cwd: root,
      stdio: 'inherit',
    }
  );

const collectFiles = (dir) => {
  const entries = readdirSync(dir);
  const files = [];

  for (const entry of entries) {
    const fullPath = resolve(dir, entry);
    const stats = statSync(fullPath);

    if (stats.isDirectory()) {
      files.push(...collectFiles(fullPath));
      continue;
    }

    files.push(fullPath);
  }

  return files;
};

const main = async () => {
  await runBuildPages();

  const tailwind = startTailwindWatch();
  let timeout = null;
  let building = false;
  let rebuildQueued = false;

  const scheduleBuild = () => {
    if (timeout) {
      clearTimeout(timeout);
    }

    timeout = setTimeout(async () => {
      if (building) {
        rebuildQueued = true;
        return;
      }

      building = true;

      try {
        await runBuildPages();
      } catch (error) {
        console.error(error instanceof Error ? error.message : error);
      } finally {
        building = false;

        if (rebuildQueued) {
          rebuildQueued = false;
          scheduleBuild();
        }
      }
    }, 120);
  };

  const watchedFiles = [
    ...collectFiles(resolve(root, 'src/templates')),
    resolve(root, 'scripts/render-partials.mjs'),
  ];

  const watchers = watchedFiles.map((file) => watch(file, scheduleBuild));

  const shutdown = (code = 0) => {
    for (const watcher of watchers) {
      watcher.close();
    }
    tailwind.kill('SIGTERM');
    process.exit(code);
  };

  tailwind.on('exit', (code) => shutdown(code ?? 0));
  process.on('SIGINT', () => shutdown(0));
  process.on('SIGTERM', () => shutdown(0));
};

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
