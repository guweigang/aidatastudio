import hashlib,json,os,subprocess
from pathlib import Path
root=Path(os.environ['RUNNER_TEMP'])/'attachment-ocr-evidence'
files=[Path(p) for p in (root/'installed-files.txt').read_text().splitlines()]
worker=next(p for p in files if p.name=='vtable-attachment-ocr' and 'attachment-ocr' in str(p))
runtime=worker.parent.parent
manifest=json.loads((runtime/'manifest.json').read_text())
assert manifest['platform']=='linux-x86_64'
for name,digest in manifest['files'].items():
    assert hashlib.sha256((runtime/name).read_bytes()).hexdigest()==digest,name
assert os.access(worker,os.X_OK)
env=dict(os.environ,PATH='/usr/bin:/bin')
for key in list(env):
    if key.startswith(('LD_','DYLD_','TESSDATA_')):del env[key]
backend=next(p for p in files if p.name=='vtable-sidecar')
empty=root/'empty-cwd';empty.mkdir(exist_ok=True)
env.update(VTABLE_APP_DATA_DIR=str(root/'installed-app'),VTABLE_USER_WORKSPACE_ROOT=str(root/'installed-workspaces'),LIBDUCKDB_DIR=str(backend.parent.parent/'runtime/libs'))
initialized=json.loads(subprocess.check_output([str(backend),'ensure-system-workspace'],env=env,cwd=empty))
assert initialized['ok'],initialized
base=('libc.so','libm.so','libpthread.so','libdl.so','librt.so','ld-linux','linux-vdso','libresolv.so','libutil.so')
edges=[]
for binary in (runtime/'lib').iterdir():
    output=subprocess.check_output(['ldd',str(binary)],env=env,text=True)
    assert 'not found' not in output,(binary,output)
    for line in output.splitlines():
        if '=>' not in line:continue
        name,target=line.strip().split('=>',1);name=name.strip();target=Path(target.rsplit(' (',1)[0].strip())
        if not name.startswith(base):assert target.resolve().is_relative_to(runtime.resolve()),(binary,name,str(target))
        edges.append(dict(binary=binary.name,dependency=name,path=str(target)))
subprocess.run(['python3','source/desktop/scripts/test-attachment-ocr.py','--runtime',str(runtime),'--normalizer','source/desktop/native/attachment-ocr/target/release/attachment-normalization-probe','--output',str(root/'installed-acceptance.json')],env=env,check=True)
staged=json.loads((root/'native-acceptance.json').read_text())
installed=json.loads((root/'installed-acceptance.json').read_text())
assert staged['outputs']==installed['outputs']
(root/'installed-distribution.json').write_text(json.dumps(dict(status='passed',runtime=str(runtime),manifestFiles=len(manifest['files']),dependencyEdges=edges,executable=True,stagedAndInstalledOutputsEqual=True,installedSidecarInitializedFromEmptyCwd=True),indent=2)+'\n')
