#!/usr/bin/env python3
"""Container host only: exact scoped dlopen run, no build/install in guest slot."""
import argparse,hashlib,json,os,secrets,stat,subprocess,sys
from pathlib import Path
L=Path(os.environ.get('QV_FOUNDATION_LANE', Path(__file__).resolve().parent)).resolve()
W=L.parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline', action='store_true', help='select unmodified source-built Stage41b')
parser.add_argument('--full-strong', action='store_true', help='use the entire Foundation strong-import manifest')
options=parser.parse_args()
record=json.loads((L/'prepared-private.json').read_text())
root=Path(record['root'])
assert root == L/'private-install/usr/local/libexec/darling'
for name,path in {'foundation':L/'superproject/src/external/foundation','swift':L/'swift'}.items():
    actual=subprocess.check_output(['git','-C',str(path),'rev-parse','HEAD'],text=True).strip()
    assert actual==record['commits'][name], 'source changed since private preparation'
    assert not subprocess.check_output(['git','-C',str(path),'status','--porcelain','--untracked-files=all'],text=True).strip(), 'dirty source'
for relative,digest in record['payload_sha256'].items():
    assert not (root/relative).is_symlink() and (root/relative).stat().st_nlink==1, relative
    assert hashlib.sha256((root/relative).read_bytes()).hexdigest()==digest, relative
fixture=record.get('fixture', {'path':str(L/'native-build/load-exports')})
fixture_path=Path(fixture['path'])
if 'sha256' in fixture:
    assert hashlib.sha256(fixture_path.read_bytes()).hexdigest()==fixture['sha256'], 'fixture changed'
if options.baseline:
    root=W/'stage41b/usr/local/libexec/darling'
    assert root.is_dir(), 'source-built baseline install missing'
    for relative,digest in record.get('baseline_payload_sha256',{}).items():
        if digest is None:
            assert not (root/relative).exists(), relative
        else:
            assert hashlib.sha256((root/relative).read_bytes()).hexdigest()==digest, relative
launcher=W/'parallel/stage41/build/src/startup/darling'
assert not launcher.stat().st_mode & stat.S_ISUID
run_id=secrets.token_hex(4)
prefix=W/f'p/if-{run_id}'
assert len(str(prefix).encode())<=83 and not prefix.exists() and not prefix.is_symlink()
prefix.parent.mkdir(exist_ok=True)
log=L/f'guest-runs/{run_id}'
log.mkdir(parents=True,exist_ok=False)
env={k:v for k,v in os.environ.items() if not k.startswith(('DYLD_','DARLING_','__mldr_','DSERVER_')) and k not in ('DPREFIX','LD_PRELOAD','LD_LIBRARY_PATH')}
env.update(DPREFIX=str(prefix),DARLING_NONROOT='1',DARLING_INSTALL_PREFIX=str(root.parent.parent))
results=[]
def run(name,args):
    with (log/f'{name}.log').open('x') as output:
        command=([str(W/'dashboard/qv-shutdown'),str(launcher)] if args==['shutdown']
                 else [str(launcher),*args])
        proc=subprocess.run(command,env=env,stdout=output,stderr=subprocess.STDOUT)
    results.append({'step':name,'returncode':proc.returncode,'args':args})
    return proc.returncode
guard=W/'dashboard/qv-host-guard'
snapshot=log/'host-folders.before'
host_guard={'snapshot':None,'verify':None}
def guard_step(action):
    with (log/f'host-guard-{action}.log').open('x') as output:
        code=subprocess.run([str(guard),action,str(snapshot)],stdout=output,stderr=subprocess.STDOUT).returncode
    host_guard[action]=code
    return code
status=1
started=False
error=None
try:
    if guard_step('snapshot'):raise RuntimeError('host-folder snapshot failed')
    started=True
    code=run('initialize',['shell','/usr/bin/true'])
    if code:
        text=(log/'initialize.log').read_text()
        if 'shellspawn' in text.lower() and 'timeout' in text.lower():
            run('startup-shutdown',['shutdown'])
            code=run('initialize-retry',['shell','/usr/bin/true'])
    if code:raise RuntimeError('initialization failed')
    if run('initial-shutdown',['shutdown']):raise RuntimeError('shutdown failed')
    # Initialization and shutdown happen before writing anything into DPREFIX.
    owned=prefix/'Applications/imp-foundation'
    owned.mkdir(exist_ok=False)
    import shutil
    payloads={'load-exports':fixture_path,
       'Foundation.txt':L/'superproject/src/external/foundation/test/imports'/('strong-exports.txt' if options.full_strong else 'exports.txt'),
       'Darwin.txt':L/'swift/tests/darwin-foundation-imports/exports.txt',
       'swiftFoundation.txt':L/'swift/tests/foundation-imports/exports.txt'}
    for name,source in payloads.items():shutil.copy2(source,owned/name)
    args=['shell','/Applications/imp-foundation/load-exports',
       '/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation','/Applications/imp-foundation/Foundation.txt',
       '/usr/lib/swift/libswift_DarwinFoundation1.dylib','/Applications/imp-foundation/Darwin.txt',
       '/usr/lib/swift/libswiftFoundation.dylib','/Applications/imp-foundation/swiftFoundation.txt']
    status=run('dlopen-all-exports',args)
except Exception as exc:
    error=str(exc)
finally:
    try:
        if started and run('final-shutdown',['shutdown']):status=1
    except Exception as exc:
        error=str(exc)
        status=1
    finally:
        if host_guard['snapshot']==0:
            try:
                guard_status=guard_step('verify')
                if guard_status:status=guard_status
            except Exception as exc:
                error=str(exc)
                status=1
    (log/'result.json').write_text(json.dumps({'outcome':'partial' if status==0 else 'failed', 'dlopen_test_passed':status==0,
       'scope':'all strong imports' if options.full_strong else 'provided export subset',
       'baseline':options.baseline,'runtime_root':str(root),'fixture_sha256':hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
       'manifest_sha256':{name:hashlib.sha256(source.read_bytes()).hexdigest() for name,source in payloads.items()} if started and 'payloads' in globals() else {},
       'prefix':str(prefix),'steps':results,'prepared':record,'host_guard':host_guard,'error':error},indent=2)+'\n')
    print(log)
sys.exit(status)
