# Ground-truth input inventory

Inspected 2026-10-09, baseline `8b64cdcff3365e0ae4c5401bf2e799abd3dca649`, branch `main`, commit date 2026-10-09T22:33:30+07:00. Working tree was clean before the refresh. [Machine inventory](INPUT_INVENTORY.json) records each real path, type, bytes, SHA-256, inspection mode, headings, Dart classes/routes, test titles and per-file last tracked commit/date. It is a baseline snapshot; later new files are in the final manifest/diff and [current disk tree](REPO_TREE.md).

| Artifact | Read status / evidence |
|---|---|
| Current user attachment `Văn bản đã dán.txt` | READ — current engineering directive, including sections 1–17 and official launchpad. Attachment remains outside Git. |
| `docs/ARCHITECTURE_BLUEPRINT_V1.md` | READ — baseline architecture, dated research snapshot and 17 ADRs. Audit corrections supersede operational assumptions. |
| Earlier 2,491-line master directive | **MISSING SOURCE — USER ACTION NEEDED**. Historical memory reports it existed; its full supplied original is not in this checkout. |
| Legacy docs archive outside current `docs/` | **MISSING SOURCE — USER ACTION NEEDED**. Existing 101 docs were inspected; no external archive was fabricated. |
| Teacher assignment rubric | **MISSING SOURCE — USER ACTION NEEDED**. Minimum service count/container/broker requirements cannot be extracted without it. |
| Repository | 2,358 non-generated files in baseline scan; 126 mobile source files; 216 Dart files including tests; 1,613 PNGs. Text was machine-read recursively; focused source review covered main/router, Auth adapter/controller, learning reducer/repository, practice interfaces, configs, tests and canonical documents. |
| Screens/assets | Binary hashes and metadata for the full set; one existing password QA capture visually sampled. Historical screenshots do not prove current installation. |
| Dependency state | Mobile pubspec/lock pins current mock dependencies. Node/pnpm were present; backend packages/lock were missing at baseline and supplied in this refresh. |
| Flutter / Dart / Android | Fresh local Flutter 3.47.0, Dart 3.13.0, Android SDK/build-tools 36, JBR 25.0.3. `flutter doctor -v` reports some Android licenses unaccepted; no Android device attached. |
| CI | Existing Android verification/build workflow; iOS simulator build is manual dispatch. New backend workflow is a file, not proof it ran on GitHub. |
| Appwrite | No verified project/organization expiry, resources, deployed service revision or live transaction/permission receipt supplied. Example config is not account evidence. |

Excluded caches, installs, build outputs, `.git`, private environment files, local.properties, symlinks and secret directories. Logs/binaries receive metadata rather than contents. No secrets were copied. Latest SDK/package releases are not substituted for the tested Flutter lock.
