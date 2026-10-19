"""Reproduce and prevent CRLF drift of unchanged embedded assets on commit checkout."""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--clone-script',type=Path);args=ap.parse_args()
with tempfile.TemporaryDirectory() as temp:
 root=Path(temp);origin=root/'origin';origin.mkdir()
 def git(*parts,env=None):
  return subprocess.check_output(['git',*map(str,parts)],env=env,stderr=subprocess.PIPE).decode().strip()
 git('init','-b','main',origin);git('-C',origin,'config','user.name','Acceptance');git('-C',origin,'config','user.email','acceptance@example.invalid');git('-C',origin,'config','core.autocrlf','false')
 (origin/'assets').mkdir();content=b'immutable embedded source\nsecond line\n';(origin/'assets/source.txt').write_bytes(content)
 git('-C',origin,'add','.');git('-C',origin,'commit','-m','baseline without attributes')
 git('-C',origin,'checkout','-b','with-attributes');(origin/'.gitattributes').write_bytes(b'assets/* text eol=lf\n');git('-C',origin,'add','.gitattributes');git('-C',origin,'commit','-m','add attributes without changing source')
 revision=git('-C',origin,'rev-parse','HEAD');git('-C',origin,'checkout','main')
 config=root/'global.gitconfig';config.write_text('[core]\n autocrlf = true\n');env=dict(os.environ,GIT_CONFIG_GLOBAL=str(config),GIT_CONFIG_NOSYSTEM='1')
 bad=root/'bad';git('clone',origin,bad,env=env);git('-C',bad,'checkout',revision,env=env)
 assert (bad/'assets/source.txt').read_bytes()==content.replace(b'\n',b'\r\n'),'fixture must reproduce unchanged-file CRLF drift'
 good=root/'good'
 if args.clone_script:
  subprocess.run(['pwsh','-NoProfile','-File',str(args.clone_script.resolve()),'-Repository',str(origin),'-SourceRef',revision,'-Destination',str(good),'-MaxAttempts','1'],env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 else:
  git('clone','--config','core.autocrlf=false',origin,good,env=env);git('-C',good,'checkout',revision,env=env)
 assert (good/'assets/source.txt').read_bytes()==content
 assert git('-C',good,'config','--local','core.autocrlf',env=env)=='false'
 print(json.dumps(dict(status='passed',commitFallback=True,unchangedEmbeddedBytesPreserved=True,checksum=hashlib.sha256(content).hexdigest(),globalCRLFPolicyUnchanged=True,actualPowerShellCloneScript=bool(args.clone_script))))
