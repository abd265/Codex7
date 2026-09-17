#!/usr/bin/env python3
"""Upload an actual simulator .app ZIP. Never logs API credentials or full responses."""
import json,os,re,sys,uuid,urllib.request,urllib.error
from pathlib import Path
BASE='https://api.appetize.io/v1/apps'
def endpoint(key):
    if key and not re.fullmatch(r'[A-Za-z0-9_-]+',key):
        raise ValueError('APPETIZE_APP_PUBLIC_KEY has invalid characters')
    return BASE+('/'+key if key else '')
def multipart(path,boundary):
    fields={'platform':'ios','fileType':'zip','note':'RiseBake 1.2 — native SwiftUI preview','appPermissions.run':'public'}
    chunks=[]
    for name,value in fields.items():
        chunks.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    chunks.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="RiseBake-simulator.zip"\r\nContent-Type: application/zip\r\n\r\n'.encode())
    chunks.extend([path.read_bytes(),f'\r\n--{boundary}--\r\n'.encode()])
    return b''.join(chunks)
def main():
    token=os.environ.get('APPETIZE_API_TOKEN','')
    if not token:raise SystemExit('Missing APPETIZE_API_TOKEN. Add it as a secret in Codemagic.')
    path=Path('artifacts/RiseBake-simulator.zip')
    if not path.is_file():raise SystemExit('Build the native simulator app first.')
    from zipfile import ZipFile
    with ZipFile(path) as z:
        if 'RiseBake.app/RiseBake' not in z.namelist():raise SystemExit('Refusing to upload: this is not the native simulator bundle.')
    key=os.environ.get('APPETIZE_APP_PUBLIC_KEY','').strip()
    boundary='risebake-'+uuid.uuid4().hex
    request=urllib.request.Request(endpoint(key),data=multipart(path,boundary),headers={'X-API-KEY':token,'Content-Type':'multipart/form-data; boundary='+boundary},method='POST')
    try:
        with urllib.request.urlopen(request,timeout=180) as response:result=json.load(response)
    except urllib.error.HTTPError as error:
        # Error bodies may include request metadata; do not echo them into public CI logs.
        raise SystemExit(f'Appetize upload failed (HTTP {error.code}). Check token scope, app public key and account quota.')
    except urllib.error.URLError:
        raise SystemExit('Appetize could not be reached. Check its status before retrying.')
    public_key=result.get('publicKey') or key
    if not public_key or not re.fullmatch(r'[A-Za-z0-9_-]+',public_key):raise SystemExit('Appetize returned no valid public key; check the dashboard.')
    # Explicitly enable the user-requested online preview with the documented JSON API.
    permissions=urllib.request.Request(endpoint(public_key),data=json.dumps({'appPermissions':{'run':'public'}}).encode(),headers={'X-API-KEY':token,'Content-Type':'application/json'},method='POST')
    try:
        with urllib.request.urlopen(permissions,timeout=60) as response:response.read()
    except (urllib.error.HTTPError,urllib.error.URLError):
        raise SystemExit('App uploaded, but public preview permissions could not be confirmed. Check the Appetize dashboard.')
    url='https://appetize.io/app/'+public_key
    safe={'publicKey':public_key,'previewURL':url,'platform':'ios','versionCode':result.get('versionCode')}
    Path('artifacts/appetize-result.json').write_text(json.dumps(safe,indent=2)+'\n')
    Path('artifacts/Appetize-preview.txt').write_text(url+'\n')
    print('Native iOS preview: '+url)
    if not key:print('For subsequent builds, set APPETIZE_APP_PUBLIC_KEY to '+public_key+' to update this same preview.')
if __name__=='__main__':main()
