---
name: build
description: Android AAB를 빌드하는 워크플로우. 정식 빌드는 버전코드 증가와 커밋까지, 테스트 빌드는 버전 변경 없이 빌드만 진행. 사용자가 빌드, 테스트 빌드, AAB, 스토어 업로드용 파일 생성 등을 요청할 때 사용.
---

## 빌드 종류

먼저 어떤 빌드인지 정한다. 유저 요청에 "테스트", "코드 올리지 말고" 같은 말이 있으면 테스트 빌드, 그 외에는 정식 빌드다. 애매하면 유저에게 묻는다.

| 항목 | 정식 빌드 | 테스트 빌드 |
|------|-----------|-------------|
| 버전코드 | 1 올림 | 그대로 둠 |
| `export_presets.cfg` | 수정 | 수정하지 않음 |
| 산출물 파일명 | `export_path` 그대로 | `export_path` 이름 뒤에 `_test`를 붙인 경로 |
| 커밋 | 버전 변경 커밋 | 커밋 없음 |

## 빌드 절차

### 1단계: 버전 정리

- 현재 버전은 git 태그가 아니라 `export_presets.cfg` Android 프리셋의 `version/code`와 `version/name`이 기준이다.
- **정식 빌드:** `version/code`를 1 올리고, `export_path` 파일명 끝 번호 `..._{code}.aab`도 같은 번호로 맞춘다. `version/name`을 바꿀지 유저에게 확인한다.
- **테스트 빌드:** 아무것도 바꾸지 않는다.

### 2단계: 서명 정보 받기

- 키스토어로 서명해야 한다.
- 키스토어 파일 경로, alias, 비밀번호를 유저에게 묻는다.

### 3단계: 빌드

환경변수로 서명 정보를 넘기고 gradle 빌드를 실행한다. 테스트 빌드는 출력 경로를 인자로 넘겨서 정식 산출물을 덮어쓰지 않게 한다.

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=<키스토어 경로> \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias> \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<비밀번호> \
godot4 --headless --export-release "Android" [테스트 빌드일 때 출력 경로]
```

### 4단계: 산출물 확인

- Godot이 최종 복사를 빠뜨릴 때가 있다.
- `android/build/build/outputs/bundle/standardRelease/build-standard-release.aab`를 이번 빌드의 출력 경로로 직접 복사하고, 파일이 생겼는지 확인한다.
- 결과로 빌드 종류, 버전코드, 버전이름, 산출물 경로를 알려준다.

### 5단계: 버전 변경 커밋

- **정식 빌드만** `export_presets.cfg` 변경을 dev 브랜치에 커밋한다.
- 커밋 메시지 예: `버전 코드 18 빌드 반영`
- 테스트 빌드는 커밋하지 않는다.
