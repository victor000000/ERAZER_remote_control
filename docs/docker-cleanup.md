# Native environment and Docker cleanup

Reviewed **2026-10-23, Asia/Shanghai**.

ERAZER Remote Control runs directly on Windows with PowerShell. It has no
Dockerfile, Compose service, container image or Docker volume to migrate.
Use the [local setup](../README.md#local-environment-no-docker-required) and
[native test commands](testing.md). Python helpers use the standard library.
Keep Windows Task Scheduler, installed SQX, SSH and MWB on their intended host.

## Local cleanup scope

The initial October 23 read-only inventory found Docker Desktop and containers for `data_providers`, `dte_21_screener` and `my_brain_work`,
images for their runners, and `multi-stack` volumes. These belong to other
projects. The inventory changed during inspection; always refresh it before
removal. Raw inspection and removal evidence stays privately in ignored
`out/docker-cleanup/2026-10-23/`.

The user authorized machine-wide removal, then explicitly requested no backups.
Backup copies created by this chat were deleted. No additional backups are part
of the cleanup.

## Verified removal

Docker Desktop and its virtual disks were removed concurrently by another
process during this pass. Subsequent verification confirmed:

- No Docker Desktop processes, uninstall entry or startup entry remain.
- Docker Desktop's installation directory, local/roaming data directories,
  Windows `.docker`, and standard ProgramData/Program Files Docker directories
  are absent. Its image/container/volume storage virtual disks are gone.
- Only Ubuntu remains registered with WSL. Ubuntu is still running and the
  bind-mounted project source directories remain present.

The Ubuntu `docker.io` package was purged successfully. Its stale socket, unit
masks and Docker group were removed separately. Shared container runtimes and
network packages were preserved; no blanket dependency autoremove was run.

Keep the Ubuntu WSL distribution and repository files. Do not use
`wsl --shutdown` or unregister Ubuntu to clean Docker: this workspace runs there.
At the user's subsequent request, the remaining Docker backup sets in
`/home/vic/docker-retirement-20261023/` and
`/home/vic/qc_work/.local/docker-cleanup-20261023/` were deleted as well.
The retired Docker Compose copy and old Docker virtual environment under
`/home/vic/.local/share/dte-21-screener/` were removed; the active native
`/home/vic/dte_21_screener/.venv/` was preserved. Deletion evidence is recorded
in `out/docker-cleanup/2026-10-23/backup-removal.json`.
Verification evidence is in `out/docker-cleanup/2026-10-23/verification.json`.
