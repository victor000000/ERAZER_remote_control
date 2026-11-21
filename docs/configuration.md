# Configuration reference

Source contract: [defaults](../config/defaults.psd1),
[overlay example](../config/local.example.psd1), and
[loader](../src/ERAZER.RemoteControl/Core.ps1). These are source defaults, not
measurements of a deployed machine. Do not publish private endpoints or copy
private host overlays into an issue or review.

## Loading and precedence

```powershell
$config = .\scripts\Initialize-Toolkit.ps1
$config.SchemaVersion
```

The loader imports the module and returns the merged configuration. Try an
explicit overlay offline using the example data file included in the repository.

```powershell
$config = .\scripts\Initialize-Toolkit.ps1 -ConfigPath .\config\defaults.psd1 -LocalConfigPath .\config\local.example.psd1
$config.SchemaVersion
```

The example also returns schema version `1`. For deployment, copy the example
to a private path such as `out/operator.local.psd1`, edit it for the host and
pass that file with `-LocalConfigPath`. The loader only reads an overlay when
you supply its path.
Relative paths resolve against the calling process's working directory.

Nested hashtables merge recursively; scalar values and arrays replace the base.
There is no environment-variable interpolation or automatic secret resolution
in the loader. Unknown extra keys are retained. Missing files, unsupported schema,
missing core sections/SQX strings and nonpositive proxy thresholds cause errors.
Selected API-origin/project syntax is checked, not full host readiness.

## Schema 1

| Key | Source behavior / default |
| --- | --- |
| `SchemaVersion` | Must equal `1`; independent of package/release version |
| `Target.HostName`, `Target.User` | Intended Windows host/user; used by operation guards; set privately for an actual installation |
| `Target.SshAlias`, `Target.LanAddress` | Environment-specific metadata; does not reconfigure the root connector's embedded discovery rules |
| `Target.DeployRoot` | Intended deployment metadata; staging still requires explicit DestinationPath |
| `Sqx.InstallDirectory` | Defaults to `C:\StrategyQuantX145`; select the verified actual installation |
| `Sqx.Project` | Defaults to `S001_reproduce_project`; project names reject separators/control characters/quotes and leading/trailing whitespace |
| `Sqx.ApiBase` | Defaults to `http://127.0.0.1:5050`; HTTP(S) origin only, without credentials, path, query or fragment |
| `Sqx.TaskName` | Defaults to `SQX-Task1-Headless`; reserved preserving-task name, rejected by generic registration |
| `Sqx.GuiTaskName` | Defaults to `StartTradingAppsAtLogon`; generic GUI control starts the existing reviewed task |
| `Sqx.LogDirectory` | Native stdout/stderr destination; must be writable on the operation host |
| `Proxy.Servers` | Case-sensitive SSID map; empty endpoint disables that network's proxy; `<gateway>` is substituted only with a valid IPv4 gateway |
| `Proxy.FailureThreshold` | Default `3`. Use 1–99 consecutive failed probes for the same endpoint before Disable. |
| `Proxy.UnknownThreshold` | Default `3`. Use 1–99 missing observations before Disable. |
| `Proxy.Mt5Directory` | Selected MT5 installation; only used for explicit MT5 proxy update |
| `Controller.ExpectedTasks` | Source autostart expectations; currently contains legacy OMR task names and requires reconciliation with the Mihomo owner before restoration |
| `Controller.MihomoRegistrar` | Controller-local registrar path; not downloaded or deployed by this project |

The loader checks that both thresholds are positive. A value of `100` can load
successfully and then fail parameter validation in the watcher. Test a private
overlay with `-DryRun -SimulateSsid 'unconfigured-example'` before enabling a watcher.

## Script-specific configuration

The common `ConfigPath`/`LocalConfigPath` options apply to generic SQX, proxy and
system helpers listed in [command reference](command-reference.md). They do not
apply to every script. Rebuild-SqxProject has explicit archive/path parameters.
The root connector, standalone connectivity guard, MWB installer, S001 launchers
and Python transport have their own arguments or embedded environment assumptions.
Inspect their current source before transferring them to another machine.

A nonreserved TaskName is needed for an independently reviewed generic task.
Renaming the actual preserving task is not a workaround for its protection.
A private installation override also cannot make the generic CLI parser into an
authenticated GUI monitor. See [troubleshooting](troubleshooting.md).

## Packaging and secrets

[The deployment manifest](../config/deployment.psd1) lists every staged file.
It is not a package dependency resolver. Private overlays, licenses, credentials,
SSH identities and ignored monitor helpers are excluded. Staging does not create
private directories/keys or provision vendor software. Never add those files to
make a fresh clone appear to contain a deployed environment.
