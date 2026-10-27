# SQL Anywhere PHP Driver

The SAP SQL Anywhere extension for PHP (`sasql_*` functions), with prebuilt
binaries for Windows and Linux, including builds for **PHP 8.5**.

The source code comes from SAP's
[SQL Anywhere PHP driver](https://help.sap.com/docs/SUPPORT_CONTENT/sqlany/3362971282.html#content/view/451071032)
(source version 2.0.19). This repository adds a fix for building ZTS with GCC 14
and build scripts for newer PHP versions. See [Changes](Changes) for the history.

## Prebuilt binaries

The `dist/` folder uses the same layout and file names as SAP's distribution.
Each version has ready-to-download archives next to the unpacked files:

```
dist/
└── php-<major.minor>/
    ├── SQLAnywhere-php-<major.minor>_Linux.tar.gz   (contents of linux/)
    ├── SQLAnywhere-php-<major.minor>_Windows.zip    (contents of windows/)
    ├── linux/
    │   └── lib64/
    │       ├── php-<ver>_sqlanywhere.so      -> php-<ver>_sqlanywhere.so.1    (NTS)
    │       └── php-<ver>_sqlanywhere_r.so    -> php-<ver>_sqlanywhere_r.so.1  (ZTS / thread safe)
    └── windows/
        ├── bin32/                                                        (x86)
        └── bin64/                                                        (x64)
            ├── php-<ver>_sqlanywhere.dll                                 (TS)
            └── php-<ver>_sqlanywhere_nts.dll                             (NTS)
```

| PHP | Windows x64 | Windows x86 | Linux x64 | Driver version | Built by |
|-----|-------------|-------------|-----------|----------------|----------|
| 8.1 | TS, NTS     | TS, NTS     | NTS, ZTS  | 2.0.20.1       | SAP (unchanged) |
| 8.2 | TS, NTS     | TS, NTS     | NTS, ZTS  | 2.0.20.1       | SAP (unchanged) |
| 8.5 | TS, NTS     | TS, NTS     | NTS, ZTS  | 2.0.19.1       | this repo, `build/` |

The file name carries `<major.minor>.0` (for example `php-8.5.0_…`) but the
binary works with every patch release of that minor version.

Choosing a file:

- **Thread safety** must match your PHP. Check with `php -i | grep "Thread Safety"`
  (Windows: `php -i | findstr "Thread"`).
  - Windows: TS → `php-<ver>_sqlanywhere.dll`, NTS → `php-<ver>_sqlanywhere_nts.dll`
  - Linux: NTS → `php-<ver>_sqlanywhere.so`, ZTS → `php-<ver>_sqlanywhere_r.so`
- **Architecture** must match your PHP (`bin64` for 64-bit, `bin32` for 32-bit).

## Requirements

The extension is a thin wrapper around the SQL Anywhere C API, which it loads at
runtime. The SQL Anywhere client (for example SQL Anywhere 17) must be installed
on the machine. The client installer can be downloaded from SAP:
[SAP SQL Anywhere client download](https://help.sap.com/docs/SUPPORT_CONTENT/sqlany/3362971128.html).


- Windows: `dbcapi.dll` must be on `PATH` (the SQL Anywhere installer adds `Bin64`/`Bin32`).
- Linux: `libdbcapi.so` (NTS) or `libdbcapi_r.so` (ZTS) must be found by the
  dynamic loader, e.g. by sourcing the SQL Anywhere environment script:

  ```sh
  . /opt/sqlanywhere17/bin64/sa_config.sh
  ```

  For PHP-FPM or Apache, set `LD_LIBRARY_PATH` in the service environment too.

## Installation

1. Copy the matching file into PHP's extension directory
   (`php -i | grep extension_dir`).
2. Enable it in `php.ini`:

   ```ini
   ; Windows
   extension=php-8.5.0_sqlanywhere_nts.dll

   ; Linux
   extension=php-8.5.0_sqlanywhere.so
   ```

3. Verify:

   ```sh
   php -m | grep sqlanywhere
   ```

### Configuration (`php.ini`)

| Setting | Default | Description |
|---------|---------|-------------|
| `sqlanywhere.allow_persistent` | `1` | Allow persistent connections (`sasql_pconnect`) |
| `sqlanywhere.max_persistent_connections` | `-1` | Maximum persistent connections (`-1` = unlimited) |
| `sqlanywhere.max_connections` | `-1` | Maximum connections (`-1` = unlimited) |
| `sqlanywhere.auto_commit` | `1` | Auto commit by default |

## Usage

```php
<?php
$conn = sasql_connect("UID=DBA;PWD=sql;Server=demo17;DBN=demo");
if (!$conn) {
    die("Connection failed: " . sasql_error());
}

$stmt = sasql_prepare($conn, "SELECT ID, Surname FROM Employees WHERE DepartmentID = ?");
$dept = 100;
sasql_stmt_bind_param($stmt, "i", $dept);
sasql_stmt_execute($stmt);
sasql_stmt_bind_result($stmt, $id, $surname);
while (sasql_stmt_fetch($stmt)) {
    echo "$id $surname\n";
}
sasql_stmt_close($stmt);

$result = sasql_query($conn, "SELECT * FROM Departments");
while ($row = sasql_fetch_assoc($result)) {
    print_r($row);
}
sasql_free_result($result);

sasql_close($conn);
```

The full function reference is in the SAP SQL Anywhere documentation
("SQL Anywhere PHP API reference").

## Building from source

### Linux (Docker)

Builds NTS and ZTS with the official `php:<ver>-cli` and `php:<ver>-zts` images:

```sh
build/build-linux.sh 8.5
# -> dist/php-8.5/linux/lib64/ and dist/php-8.5/SQLAnywhere-php-8.5_Linux.tar.gz
```

Or manually, with the PHP development headers installed:

```sh
phpize
./configure --with-sqlanywhere
make
# -> modules/sqlanywhere.so
```

### Windows (x64 and x86)

Requirements: Visual Studio Build Tools with the MSVC toolset PHP was built with
(PHP 8.5: MSVC 14.44, component `Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64`)
and the Windows 10/11 SDK. The script downloads the PHP devel packs and
`php-sdk-binary-tools` itself.

```bat
build\build-windows.bat 8.5.12-1 14.44 x64
rem -> dist\php-8.5\windows\bin64\
build\build-windows.bat 8.5.12-1 14.44 x86
rem -> dist\php-8.5\windows\bin32\
rem each run repacks dist\php-8.5\SQLAnywhere-php-8.5_Windows.zip with all bin* folders
```

PHP refuses to load an extension linked with a newer MSVC than PHP itself, so
the toolset must not be newer than the one used for your PHP build.

## License

- The driver source code is © SAP SE or an SAP affiliate company, licensed under
  the Apache License 2.0 — see [license.txt](license.txt) (SAP's original notice).
- The changes and build scripts in this repository are also released under the
  Apache License 2.0 — see [LICENSE](LICENSE). Modified SAP files say so in
  their header; all changes are listed in [Changes](Changes).
- The PHP 8.1 and 8.2 binaries in `dist/` are SAP's own builds, redistributed
  unchanged.

SAP and SQL Anywhere are trademarks of SAP SE. This project is not affiliated
with or endorsed by SAP.
