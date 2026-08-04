[English](README.md) | **Korean** | [Japanese](README.ja.md)

# mxpak

글로벌 캐싱 및 하드 링크를 갖춘 Mendix 패키지 관리자 및 작업 공간 중복 제거기입니다.

각 위젯을 한 번 다운로드하고, 전역적으로 캐시하고, 추가 디스크 비용 없이 모든 프로젝트에서 공유하세요. 그런 다음 한 번에 나머지 공유 자산(라이브러리, 테마 리소스)의 중복을 제거합니다.

## 작동 방식

mxpak에는 `~/.mxpak/store/{sha256}/`의 동일한 콘텐츠 주소 지정 가능 저장소에서 지원되는 두 가지 보완 메커니즘이 있습니다.

1. **`mxp install` — 위젯 종속성 관리자.** Mendix Marketplace에서 `.mpk` 파일을 다운로드하고 SHA-256 해시를 통해 CAS에 저장한 다음 `<project>/widgets/`에 하드 링크합니다. 재현성을 위해 `mxpak.lock`를 통해 잠겼습니다.
2. **`mxp scan` — 작업 공간 중복 제거기.** 작업 공간 아래의 모든 프로젝트를 검사하고, `install`가 관리하지 않는 공유 파일(`userlib/`/`vendorlib/`의 Java 라이브러리, `themesource/`의 Mendix 표준 테마 자산)을 해시하고, 중복 파일을 단일 CAS에 저장된 하드 링크로 대체합니다. 복사.

캐시와 프로젝트가 다른 드라이브에 있는 경우(하드 링크가 작동하지 않는 경우) mxpak는 자동으로 일반 파일 복사로 대체됩니다.

## 설치

**전제 조건** — Erlang/OTP 26+가 `PATH`에 있어야 합니다(`escript` 명령 사용 가능).

- 맥OS: `brew install erlang`
- 윈도우즈: `winget install Erlang.ErlangOTP`
- Linux: `sudo apt-get install erlang`(또는 해당 배포판의 동급 제품)

### 한 줄짜리

**맥OS/리눅스**

```sh
curl -fsSL https://github.com/glendix-labs/mxpak/releases/latest/download/install.sh | sh
```

**윈도우(파워셸)**

```powershell
iwr -useb https://github.com/glendix-labs/mxpak/releases/latest/download/install.ps1 | iex
```

두 스크립트 모두 `mxp` escript를 `~/.mxpak/bin/`(macOS/Linux) 또는 `%USERPROFILE%\.mxpak\bin\`(Windows)에 배치합니다.

**Windows** — 설치 프로그램이 사용자 `PATH`에 디렉토리를 자동으로 추가하지만 변경 사항은 **새** 터미널 창에만 적용됩니다. 동일한 세션에서 즉시 `mxp`를 사용하려면:

```powershell
$env:PATH = "$env:USERPROFILE\.mxpak\bin;$env:PATH"
mxp --version
```

**macOS/Linux** — 쉘 rc 파일에 직접 디렉터리를 추가하세요.

```sh
export PATH="$HOME/.mxpak/bin:$PATH"     # add to ~/.zshrc, ~/.bashrc, etc.
mxp --version
```

### 문제 해결

- **`escript: ... command not found`** — Erlang/OTP가 없습니다. 위의 필수 구성 요소 단계를 통해 설치하고 설치 프로그램을 다시 실행하세요.
- **`mxp: command not found`(설치 후)** — 새 터미널을 열거나 위와 같이 현재 세션에 PATH를 적용합니다.
- **`undefined function mxpak:main/0`** — 오래된 escript 번들입니다. 최신 릴리스를 가져오려면 설치 프로그램을 다시 실행하세요.

### 출처에서

```sh
git clone https://github.com/glendix-labs/mxpak.git
cd mxpak
gleam run -m gleescript    # produces ./mxpak — rename to mxp and place on PATH
```

## 사용법

```
mxp <command> [options]
```

| 명령 | 설명 |
|---|---|
| `install [project_root]` | 구성에서 모든 위젯 확인 및 설치(잠금 파일 선호) |
| `add <name> --version <v>` | 구성에 위젯을 추가하고 설치 |
| `remove <name>` | 구성에서 위젯 제거 |
| `update [name]` | 위젯 업데이트(잠금 해제, 다시 해결) |
| `marketplace [project_root]` | Mendix Marketplace용 대화형 TUI 브라우저 |
| `outdated [project_root]` | 사용 가능한 업데이트가 포함된 위젯 목록 |
| `list [project_root]` | 설치된 위젯 목록 |
| `info <name>` | 위젯 세부정보 표시 |
| `audit [project_root]` | 설치된 모든 `.mpk` 파일의 SHA-256 무결성 확인 |
| `cache clean` | 글로벌 캐시 정리 |
| `scan [path]` | 작업 영역 아래의 모든 프로젝트에서 `*.mpk`, `*.jar` 및 `themesource/**` 중복 제거 |
| `status [path]` | 프로젝트별 중복 제거 통계 및 디스크 절감량 표시 |

## 구성

프로젝트의 TOML 구성에 `[tools.mxpak]` 섹션을 추가합니다.

```toml
[tools.mxpak]
mode = "mpk"
widgets_dir = "widgets"

[tools.mxpak.widgets.Badge]
version = "3.2.2"
id = 50325

[tools.mxpak.widgets."com.mendix.widget.web.Datagrid"]
version = "2.22.3"
id = 116540
```

`mxp install`를 실행하면 재현 가능한 빌드를 위해 정확한 버전과 SHA-256 해시를 고정하는 잠금 파일(`mxpak.lock`)이 생성됩니다.

## 작업공간 중복 제거

`mxp scan`는 실행 위치에 따라 스캔 대상을 자동 감지합니다.

```sh
# Case 1 — inside a single Mendix project (a `*.mpr` is in the directory):
cd ~/Mendix/TSVE4HMC-main
mxp scan         # scans this project only
                 # its assets are absorbed into the global CAS at ~/.mxpak/store/
                 # future scans of any other project automatically dedup against them

# Case 2 — a directory whose immediate children are Mendix projects:
cd ~/Mendix      # contains TSVE4HMC-main/, ChartTest/, Blank/, ...
mxp scan         # scans every Mendix project (every immediate subdir with `*.mpr`)

mxp status       # works the same way (single project or workspace)
```

두 대소문자가 모두 일치하지 않으면(여기서는 `*.mpr`가 없고 직계 자식에는 없음) `scan`는 명확한 힌트와 함께 종료됩니다.

### 기본 규칙(제로 구성)

`scan`는 기본적으로 합리적인 기본값으로 작동합니다. 설정 파일이 필요하지 않습니다.

| 규칙 | 기본값 |
|---|---|
| `include` | `["*.mpk", "*.jar"]` — 위젯 및 Java 라이브러리(`widgets/`, `userlib/`, `vendorlib/`) |
| `include_dirs` | `["themesource"]` — Mendix 표준 테마 모듈(atlas_core, datawidgets 등) 이 디렉터리에서 검색된 모든 확장명 |
| `exclude_dirs` | `["deployment", "javascriptsource", "javasource", "modules", ".mendix-cache", ...]` — 빌드 아티팩트 및 프로젝트 고유 코드 |

`scan` 및 `install`는 `~/.mxpak/store/`에서 동일한 CAS를 공유합니다. `mxp install`를 통해 설치된 위젯은 이미 캐시에 하드 링크되어 있으므로 그 위의 `scan`는 사실상 작동하지 않습니다. Mendix Studio Pro가 직접 배치한 위젯은 첫 번째 `scan`의 CAS에 흡수되고 이후 중복 제거됩니다.

### 맞춤설정

위 항목을 재정의하려면 작업공간 루트에 `.mxpak-workspace.toml`을 추가하세요.

```toml
[scan]
include      = ["*.mpk", "*.jar", "*.zip"]
include_dirs = ["themesource", "shared"]
exclude_dirs = [".git", "deployment"]
```

누락된 키는 기본값으로 돌아갑니다.

### 측정된 절감액(실제 Mendix 프로젝트 16개, 총 ~23GB)

`mxp scan`는 한 번의 패스로 아래의 모든 내용을 다룹니다.

| 대상 | 합계 | 중복 제거 후 | 저장됨 | 비율 |
|---|---|---|---|---|
| `widgets/*.mpk` | 804MB | 533MB | **270MB** | 33.6% |
| userlib/vendorlib의 `*.jar` | 534MB | 222MB | **311MB** | 58.3% |
| `themesource/**` | 57MB | 15MB | **42MB** | 74.0% |
| **통합** | **1,395MB** | **770MB** | **623MB** | **44.7%** |

## 라이센스

[MPL-2.0](LICENCE)
