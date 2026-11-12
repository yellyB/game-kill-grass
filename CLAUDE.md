# 풀 좀 베겠습니다 - Godot 4.6 Idle Game

이 문서는 개발에 필요한 기술 지식과 작업 규칙만 다룬다.

## 기획 문서 가이드

기획 내용이 필요하면 코드나 이 문서에서 추측하지 말고 아래 문서를 먼저 읽는다.

| 문서 | 내용 |
|------|------|
| `docs/game-design.md` | 전체 기획: 세션, 월드, 풀, 코인, 무기, 몬스터, 보석, 파워업, UI |
| `docs/skill-tree.md` | 스킬 트리 구조, 스킬별 수치, 비용, 보석 해금 |
| `docs/image-prompts.md` | 몬스터, 플레이어, 무기 이미지 생성 프롬프트 |

- 기획 수치나 동작을 바꾸면 해당 기획 문서도 함께 고친다.
- 기획 문서와 코드가 다르면 임의로 한쪽에 맞추지 말고 유저에게 확인한다.

## 핵심 구조

### 이동과 좌표계
- 플레이어는 화면 중앙에 고정되고, `WorldRoot`가 입력의 반대 방향으로 이동한다.
- 배경은 플레이어를 따라다니며 무한하게 보인다.
- 코인, 몬스터, 상자, 드롭 아이템처럼 월드에 고정되어야 하는 노드는 `WorldRoot`의 자식으로 추가한다.

WorldRoot가 이동하므로 좌표 변환 필요:
```gdscript
# 코인에서 플레이어 위치 계산 시
var player_local_pos = get_parent().to_local(player.global_position)

# 공격 범위 계산 시, grass_spawner 로컬 좌표로 변환
var local_attack_center = attack_center - grass_spawner.global_position
```

### 풀 렌더링과 청크
- `grass_spawner.gd`가 MultiMesh 하나로 모든 풀을 그린다. 풀마다 씬을 만들지 않는다.
- 풀 데이터는 Dictionary로 관리하고, 바람 흔들림은 `grass_sway.gdshader`가 GPU에서 처리한다.
- 플레이어 주변 청크만 로드하고 멀어지면 언로드한다.
- 대칭 랜덤 오프셋으로 청크 경계가 보이지 않게 한다.
- 월드별 색상 상수: 풀은 `grass_spawner.gd`의 `WORLD_GRASS_TINTS`와 `WORLD_GRASS_COLORS`를 곱해서 쓰고, 배경은 `world_root.gd`의 `WORLD_BG_COLORS`

### Autoload
| 이름 | 역할 |
|------|------|
| `GameManager` | 코인, 스킬, 열쇠, 보석, 파워업, 분노 게이지, 공용 효과음 |
| `SessionManager` | 세션 시작, 종료, 메뉴 복귀 |
| `SaveManager` | 저장과 불러오기 |
| `WeaponManager` | 무기 텍스처, 공격력 계산 |

### 사운드
- 공용 효과음은 `GameManager`의 AudioStreamPlayer로 재생한다.
- `queue_free` 되는 노드의 효과음은 root에 붙인 AudioStreamPlayer로 재생하고, `finished`에서 해제한다.

## 개발 규칙

- GDScript 들여쓰기는 탭이 아니라 스페이스를 쓴다.
- 이미지, 사운드 같은 리소스를 커밋할 때 `.import` 파일도 함께 커밋한다. 빠지면 APK 빌드가 깨진다.
- `project.godot`의 창 크기 변경은 개발 환경 설정이므로 커밋하지 않는다.
- 유저가 말하는 월드 번호는 1부터 센다. 코드 index는 0부터다. 월드1은 index 0
- 몬스터 분노 시스템은 코드에서 `fury`라고 부른다.

## 디버그 기능
- 디버그 빌드에서 메인 메뉴의 코인 표시를 3초 안에 5번 탭하면 디버그 버튼이 나타난다.
- 디버그 모드가 켜지면 플레이어 몸체, 수집 범위, 공격 범위가 원으로 표시된다.

## 알려진 이슈 및 해결책

| 이슈 | 해결책 |
|------|--------|
| 플로팅 텍스트 값이 안 바뀜 | `add_child()` 후에 `setup()` 호출 |
| 무기 스케일 누적 | 애니메이션에서 고정 스케일 값 사용 |
| Tween "Target object freed" 경고 | `queue_free()` 대신 `remove_child()` 후 `queue_free()` |

## Git 브랜치, 빌드, 릴리즈

- **dev**: 개발 브랜치. 모든 기능 개발과 커밋은 반드시 여기서만 수행
- **main**: 프로덕션 브랜치. dev를 머지하는 것만 허용, 직접 커밋 금지
- AAB 빌드는 `build` 스킬, 머지와 릴리즈는 `/release` 스킬로 진행한다. 스킬은 `.claude/skills/`에 있다.

## 커밋 메시지 규칙

- **언어**: 한글
- **제목**: 한 줄, 변경 대상과 변경 내용 요약
  - 변경이 여러 개면 쉼표로 나열
  - 패턴: `{대상} {동작}` 또는 `{대상} {동작}: {세부 내용}`
  - 동작 예시: 추가, 수정, 개선, 제거, 교체, 상향, 최적화
- **본문**: 필요할 때만 `- ` 불릿으로 쓴다.
- 그 외 커밋 규칙은 전역 `~/.claude/CLAUDE.md`를 따른다.
- **예시**:
  - `모바일 터치 드래그 입력 안 되는 버그 수정`
  - `설정 팝업 추가: 배경음, 효과음, 진동 토글과 게임 데이터 초기화`
  - `미사용 코인 드롭 함수 제거`
  - `공격 범위, 수집 범위 틱당 증가량 상향`
