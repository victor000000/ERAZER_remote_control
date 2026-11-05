"""Read MiFi-1A8F's native device table; never change router or target settings.

An NA address is a historical/unresolved entry, not proof of live connectivity.
An address returned here still requires pinned SSH host-key and hostname checks.
"""
import json
import time
import base64
import subprocess
from datetime import datetime
from zoneinfo import ZoneInfo

ROUTER = '192.168.1.1'
TARGET = 'ERAZER-6JMHAKCD'
TARGET_MAC = '54:ae:bc:bf:6c:37'


def read_native(name):
    url = (f'http://{ROUTER}/xml_action.cgi?method=get&module=duster&file='
           f'json_{name}{int(time.time() * 1000)}')
    # Use the Windows controller's LAN routes, not the WSL/cloud network namespace.
    script = ("$ErrorActionPreference='Stop';"
              "$q=[Net.HttpWebRequest]::Create('" + url + "');"
              "$q.Proxy=$null;$q.Timeout=4000;$r=$q.GetResponse();"
              "$s=[IO.StreamReader]::new($r.GetResponseStream());"
              "try{[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s.ReadToEnd()))}"
              "finally{$s.Dispose();$r.Dispose()}")
    encoded = base64.b64encode(script.encode('utf-16le')).decode('ascii')
    reply = subprocess.run(
        ['/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe',
         '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
        capture_output=True, timeout=9, check=True)
    return json.loads(base64.b64decode(reply.stdout.strip(), validate=True))



def decoded_name(value):
    try:
        return bytes.fromhex(value).decode('utf-8', errors='replace').strip()
    except (ValueError, TypeError):
        return str(value).strip()


def main():
    result = {'at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
              'router': ROUTER, 'target': TARGET, 'router_mutations': False}
    try:
        status = read_native('homepage_info')
        ssid = bytes.fromhex(status.get('ssid', '')).decode('utf-16-be')
        result['ssid'] = ssid
        if ssid != 'MiFi-1A8F':
            raise ValueError('Router SSID differs from the expected MiFi network')
        clients = read_native('device_management_info').get('client_list', [])
        target_rows = []
        for row in clients:
            name = decoded_name(row.get('n', ''))
            if name.upper() == TARGET or row.get('m', '').lower() == TARGET_MAC:
                address = row.get('ip')
                target_rows.append({'name': name, 'mac': row.get('m'),
                                    'address': address if address not in ('NA', '', None) else None,
                                    'link_type': row.get('ct')})
        result['target_records'] = target_rows
        result['candidate_addresses'] = sorted({row['address'] for row in target_rows
                                                if row['address']})
        result['interpretation'] = ('Candidate addresses require pinned SSH verification; '
                                    'no address does not establish that the computer is off.')
    except Exception as error:
        result['error'] = str(error)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
