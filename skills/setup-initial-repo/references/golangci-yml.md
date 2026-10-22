# golangci-lint Default Config (Go)

Default `.golangci.yml` for new Go projects (golangci-lint v2). Write it to the project root verbatim unless SPEC.md or the user asks for a change. The `make lint` and `make format` targets in [go-makefile.md](go-makefile.md) read it.

- If `.golangci.yml` (or `.golangci.yaml` / `.golangci.toml` / `.golangci.json`) already exists, do not overwrite it — show the diff and ask.
- Drop the `^docs/queue/poc/` exclusion path when the project has no such directory.

```yaml
# .golangci.yml (golangci-lint v2)
version: "2"
linters:
  enable:
    - wsl_v5
  settings:
    staticcheck:
      checks:
        - "all"
        - "-ST1000"
        - "-ST1003"
        - "-ST1016"
        - "-ST1020"
        - "-ST1021"
        - "-ST1022"
        - "-QF1008"
    wsl_v5:
      default: default        # 기본 체크 세트 유지
      enable:
        - after-block         # } 뒤에는 항상 빈 줄
      branch-max-lines: 2

formatters:
  enable:
    - gofumpt        # 선택: gofmt보다 엄격한 포맷
    - golines
  settings:
    golines:
      max-len: 120
      tab-len: 4
      shorten-comments: false
      reformat-tags: false
      chain-split-dots: true
  exclusions:
    generated: lax   # "Code generated ... DO NOT EDIT" 헤더가 있는 파일은 건너뜀
```
