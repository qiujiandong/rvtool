#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
README=${README:-$repo_root/README.md}
IMAGE=${IMAGE:-ghcr.io/qiujiandong/rvtool}
ARCHITECTURE=${ARCHITECTURE:-linux/amd64}
PACKAGE_OWNER=${PACKAGE_OWNER:-qiujiandong}
PACKAGE_NAME=${PACKAGE_NAME:-rvtool}
PACKAGE_PAGE=${PACKAGE_PAGE:-https://github.com/qiujiandong/rvtool/pkgs/container/rvtool}
UPSTREAM_RELEASES=https://github.com/riscv-collab/riscv-gnu-toolchain/releases/tag

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

export DOCKER_CONFIG="$tmp_dir/docker-config"
token=${GH_TOKEN:-$(gh auth token)}
if ! printf '%s' "$token" | docker login ghcr.io -u "$PACKAGE_OWNER" --password-stdin \
  >/dev/null 2>"$tmp_dir/docker-login.err"; then
  cat "$tmp_dir/docker-login.err" >&2
  exit 1
fi

gh api "/users/$PACKAGE_OWNER/packages/container/$PACKAGE_NAME/versions?per_page=100" \
  >"$tmp_dir/versions.json"

python3 - "$tmp_dir/versions.json" >"$tmp_dir/tags" <<'PY'
import json
import sys

versions = json.load(open(sys.argv[1]))
for version in sorted(versions, key=lambda item: item["updated_at"], reverse=True):
    tags = version.get("metadata", {}).get("container", {}).get("tags", [])
    for tag in tags:
        if tag != "latest":
            print(tag)
            break
PY

{
  printf '| Image | Architecture | Upstream release | Size |\n'
  printf '| --- | --- | --- | --- |\n'

  first_tag=$(sed -n '1p' "$tmp_dir/tags")
  test -n "$first_tag"

  while IFS= read -r tag; do
    docker manifest inspect "$IMAGE:$tag" >"$tmp_dir/index.json"
    python3 - "$tmp_dir/index.json" "$ARCHITECTURE" >"$tmp_dir/platforms" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1]))
if "manifests" in manifest:
    for descriptor in manifest["manifests"]:
        platform = descriptor.get("platform", {})
        os_name = platform.get("os")
        architecture = platform.get("architecture")
        if os_name and architecture and os_name != "unknown" and architecture != "unknown":
            print(f"{os_name}/{architecture}\t{descriptor['digest']}")
else:
    print(f"{sys.argv[2]}\t")
PY

    for image_tag in $(test "$tag" = "$first_tag" && printf 'latest %s' "$tag" || printf '%s' "$tag"); do
      while IFS="$(printf '\t')" read -r architecture digest; do
        if [ -n "$digest" ]; then
          docker manifest inspect "$IMAGE@$digest" >"$tmp_dir/manifest.json"
        else
          cp "$tmp_dir/index.json" "$tmp_dir/manifest.json"
        fi
        size=$(python3 - "$tmp_dir/manifest.json" <<'PY'
import json
import sys

size = sum(layer["size"] for layer in json.load(open(sys.argv[1]))["layers"])
if size >= 1_000_000_000:
    print(f"{size / 1_000_000_000:.2f} GB")
else:
    print(f"{size / 1_000_000:.0f} MB")
PY
)
        printf '| [`%s:%s`](%s) | `%s` | [`%s`](%s/%s) | %s |\n' \
          "$IMAGE" "$image_tag" "$PACKAGE_PAGE" "$architecture" "$tag" \
          "$UPSTREAM_RELEASES" "$tag" "$size"
      done <"$tmp_dir/platforms"
    done
  done <"$tmp_dir/tags"
} >"$tmp_dir/table"

python3 - "$README" "$tmp_dir/table" <<'PY'
import pathlib
import sys

readme = pathlib.Path(sys.argv[1])
table = pathlib.Path(sys.argv[2]).read_text().rstrip()
content = readme.read_text()
start = "<!-- images:start -->"
end = "<!-- images:end -->"
before, marker, rest = content.partition(start)
if not marker:
    raise SystemExit(f"missing {start}")
old, marker, after = rest.partition(end)
if not marker:
    raise SystemExit(f"missing {end}")
readme.write_text(f"{before}{start}\n{table}\n{end}{after}")
PY
