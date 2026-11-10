"""Run release scripts against disposable Git repositories and a fake Docker CLI."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
REPOS = ('weixing-service', 'weixing-tcp-server', 'weixing-frontend')

class ReleaseWorkflowTest(unittest.TestCase):
    def run_case(self, repo_name, state):
        with tempfile.TemporaryDirectory(prefix='weixing-release-test-') as temporary:
            root = Path(temporary)
            repo = root / repo_name
            repo.mkdir()
            def git(*args, cwd=repo):
                return subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()
            git('init', '-b', 'main')
            git('config', 'user.name', 'Release Test')
            git('config', 'user.email', 'release-test@example.invalid')
            shutil.copy2(ROOT / repo_name / 'build.sh', repo / 'build.sh')
            (repo / 'Dockerfile').write_text('FROM scratch\n')
            (repo / 'source.txt').write_text('committed\n')
            git('add', '.')
            git('commit', '-m', 'initial')
            remote = root / 'remote.git'
            git('init', '--bare', str(remote))
            git('remote', 'add', 'origin', str(remote))
            git('push', '-u', 'origin', 'main')
            if state == 'dirty':
                (repo / 'source.txt').write_text('uncommitted\n')
            elif state == 'untracked':
                (repo / 'untracked.txt').write_text('untracked\n')
            elif state == 'unpushed':
                (repo / 'source.txt').write_text('unpublished\n')
                git('add', 'source.txt')
                git('commit', '-m', 'not pushed')
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            log = root / 'docker.jsonl'
            docker = bin_dir / 'docker'
            docker.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
args=sys.argv[1:]
with open(os.environ['DOCKER_TEST_LOG'],'a') as f:f.write(json.dumps(args)+'\\n')
if args[:2]==['buildx','build']:
 context=pathlib.Path(args[-1])
 assert context.is_dir(), 'release must use a Git snapshot directory'
 assert (context/'source.txt').read_text()=='committed\\n'
 assert not (context/'.git').exists()
 (context/'source.txt').write_text('build scratch, not working tree')
elif args[:3]==['buildx','imagetools','inspect']:
 if '--format' in args:
  print('linux/arm64' if os.environ.get('WRONG_SINGLE_PLATFORM') else 'linux/amd64')
  sys.exit(0)
 print('Name: test')
 print('Digest: sha256:'+('bad' if os.environ.get('BAD_DIGEST') and args[-1].endswith(':latest') else 'good'))
 if not os.environ.get('SINGLE_PLATFORM'):
  print('Platform: linux/amd64')
  if not os.environ.get('MISSING_ARM64'):print('Platform: linux/arm64')
''')
            docker.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH'], DOCKER_TEST_LOG=str(log))
            env.pop('FLEET_API_URL', None)
            env.pop('FLEET_TOKEN', None)
            if state == 'missing_arm64':env['MISSING_ARM64']='1'
            if state == 'bad_digest':env['BAD_DIGEST']='1'
            options=[]
            if state == 'custom_alias':options=['-t','candidate']
            if state in ('single_correct','single_wrong_arch'):
                options=['-p','linux/amd64'];env['SINGLE_PLATFORM']='1'
            if state == 'single_wrong_arch':env['WRONG_SINGLE_PLATFORM']='1'
            result = subprocess.run(['bash', str(repo/'build.sh'), *options], cwd=repo, env=env, capture_output=True, text=True)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            if state in ('dirty', 'untracked', 'unpushed'):
                self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(calls, [], 'invalid source must stop before Docker')
            elif state in ('missing_arm64', 'bad_digest', 'single_wrong_arch'):
                self.assertNotEqual(result.returncode, 0, 'verification failure must fail release')
            else:
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                builds = [call for call in calls if call[:2] == ['buildx','build']]
                self.assertEqual(len(builds),1,'release must use buildx')
                build = builds[0]
                self.assertEqual(build[build.index('--platform')+1], 'linux/amd64' if state=='single_correct' else 'linux/amd64,linux/arm64')
                self.assertIn('--push', build)
                revision = git('rev-parse','HEAD')
                self.assertIn('org.opencontainers.image.revision='+revision,build)
                tags=[build[i+1] for i,v in enumerate(build) if v=='-t']
                self.assertTrue(any(tag.endswith('-'+revision[:12]) for tag in tags),tags)
                self.assertTrue(any(tag.endswith(':latest') for tag in tags),tags)
                if state=='custom_alias':self.assertTrue(any(tag.endswith(':candidate') for tag in tags),tags)
                self.assertFalse(Path(build[-1]).exists(), 'temporary source snapshot must be removed')
                self.assertEqual((repo/'source.txt').read_text(),'committed\n')
                self.assertFalse(any(call[:2]==['buildx','rm'] for call in calls),'keep reusable build cache')

    def test_release_contract(self):
        for repo in REPOS:
            for state in ('dirty','untracked','unpushed','clean','missing_arm64','bad_digest','custom_alias','single_correct','single_wrong_arch'):
                with self.subTest(repo=repo,state=state):self.run_case(repo,state)

if __name__ == '__main__':unittest.main()
