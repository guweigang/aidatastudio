"""Bundle the non-glibc ELF dependency closure of all shipped sidecar executables."""
import os,shutil,subprocess
from pathlib import Path
backend=Path('source/backend').resolve()
lib=backend/'runtime/libs';lib.mkdir(parents=True,exist_ok=True)
licenses=backend/'runtime/licenses';licenses.mkdir(exist_ok=True)
base=('libc.so','libm.so','libpthread.so','libdl.so','librt.so','ld-linux','linux-vdso','libresolv.so','libutil.so')
queue=[p for folder in (backend/'bin',backend/'runtime/bin',lib,backend/'runtime/plugins') for p in (folder.iterdir() if folder.is_dir() else []) if p.is_file() and p.read_bytes()[:4]==b'\x7fELF']
seen=set()
while queue:
    binary=queue.pop()
    if binary in seen:continue
    seen.add(binary)
    output=subprocess.check_output(['ldd',str(binary)],text=True)
    assert 'not found' not in output,(binary,output)
    for line in output.splitlines():
        if '=>' not in line:continue
        name,rest=line.strip().split('=>',1);name=name.strip()
        if name.startswith(base):continue
        source=Path(rest.strip().split()[0]);dest=lib/name
        if not dest.exists():
            shutil.copy2(source,dest);queue.append(dest)
            owner=subprocess.run(['dpkg-query','-S',str(source.resolve())],capture_output=True,text=True)
            if owner.returncode==0:
                package=owner.stdout.split(': ')[0].split(':')[0]
                copyright=Path('/usr/share/doc')/package/'copyright'
                if copyright.is_file():shutil.copy2(copyright,licenses/(package+'-copyright'))
    relative=os.path.relpath(lib,binary.parent)
    subprocess.run(['patchelf','--set-rpath','$ORIGIN' if relative=='.' else '$ORIGIN/'+relative,str(binary)],check=True)
# MongoDB SDK is built from source rather than an installed distribution package.
mongo=Path(os.environ['RUNNER_TEMP'])/('mongo-c-driver-'+os.environ['MONGO_C_DRIVER_VERSION'])
for name in ('COPYING','COPYING.md','THIRD_PARTY_NOTICES'):
    if (mongo/name).is_file():shutil.copy2(mongo/name,licenses/('mongo-c-driver-'+name))
print('Staged',len(list(lib.iterdir())),'sidecar libraries for',len(seen),'ELF files')
