"""Pinned direct-LAN SSH transport, with identity checks before command execution.

Discovery never retries the supplied command. A timeout may mean it executed:
inspect remote state before deciding whether to repeat a mutation.
"""
from pathlib import Path
import base64
import gzip
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SSH = '/mnt/c/Windows/System32/OpenSSH/ssh.exe'
POWERSHELL = '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
EXPECTED_HOST = 'ERAZER-6JMHAKCD'
PRIMARY = '192.168.137.37'


def ssh_options(address):
    return [SSH, '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15',
            '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3',
            '-o', f'HostName={address}', '-o', 'HostKeyAlias=100.105.143.1',
            '-o', 'StrictHostKeyChecking=yes', 'erazer-ts']


def verify(address):
    try:
        reply = subprocess.run(ssh_options(address) + ['hostname'],
                               capture_output=True, timeout=25)
        return reply.returncode == 0 and reply.stdout.decode(errors='replace').strip() == EXPECTED_HOST
    except subprocess.TimeoutExpired:
        return False


def resolve():
    if verify(PRIMARY):
        return PRIMARY
    windows_path = 'C:' + str(ROOT).split('/mnt/c', 1)[1].replace('/', '\\')
    reply = subprocess.run([POWERSHELL, '-NoProfile', '-NonInteractive',
                            '-ExecutionPolicy', 'Bypass', '-File',
                            windows_path + '\\Connect-ERAZER.ps1', '-ResolveOnly'],
                           capture_output=True, timeout=110)
    candidates = re.findall(rb'(?m)^\s*(192\.168\.\d{1,3}\.\d{1,3})\s*$', reply.stdout)
    if reply.returncode == 0 and len(candidates) == 1:
        address = candidates[0].decode('ascii')
        if verify(address):
            return address
    raise ConnectionError('ERAZER not found through pinned HypoMux/MiFi discovery; '
                          'this does not establish that ERAZER or SQX is stopped.')


def run_powershell(script, timeout=55):
    address = resolve()
    script = "$ProgressPreference='SilentlyContinue';$ErrorActionPreference='Stop'\n" + script
    if len(script) > 2100:
        payload = base64.b64encode(gzip.compress(script.encode('utf-8'))).decode('ascii')
        compressed = ("$b=[Convert]::FromBase64String('" + payload + "');"
                  "$m=[IO.MemoryStream]::new($b);"
                  "$g=[IO.Compression.GZipStream]::new($m,[IO.Compression.CompressionMode]::Decompress);"
                  "$r=[IO.StreamReader]::new($g);$s=$r.ReadToEnd();$r.Dispose();$m.Dispose();"
                  "& ([scriptblock]::Create($s))")
        if len(compressed) < len(script):
            script = compressed
    encoded = base64.b64encode(script.encode('utf-16le')).decode('ascii')
    return subprocess.run(ssh_options(address) + ['powershell', '-NoProfile',
                          '-NonInteractive', '-WindowStyle', 'Hidden',
                          '-EncodedCommand', encoded], timeout=timeout)
