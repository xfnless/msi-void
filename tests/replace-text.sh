#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo/home/.local/bin/replace-text
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/project"
cat >"$tmp/bin/fzf" <<'EOF'
#!/bin/sh
# Select the requested 1-based input records, preserving their exact contents.
if [ "${TEST_REQUIRE_SELECT_ALL:-}" = 1 ]; then
	case " $* " in
		*'ctrl-a:select-all,ctrl-d:deselect-all,tab:toggle+down'*) ;;
		*) echo 'missing select-all bindings' >&2; exit 2 ;;
	esac
fi

live=0
initial=
for arg do
	case $arg in
		--print-query) live=1 ;;
		--query=*) initial=${arg#--query=} ;;
	esac
done
if [ "$live" = 1 ]; then
	query=${TEST_FZF_QUERY-$initial}
	for required in ' --disabled ' ' --phony ' ' --print-query ' ' --query=' 'change:reload('; do
		case " $* " in
			*"$required"*) ;;
			*) echo "missing live-search option: $required" >&2; exit 2 ;;
		esac
	done
	if [ "${TEST_REQUIRE_LIVE:-}" = 1 ] && [ "$initial" != "${TEST_INITIAL_QUERY-}" ]; then
		echo 'initial query was not prefilled' >&2
		exit 2
	fi
	if [ "${TEST_REQUIRE_LIVE:-}" = 1 ]; then
		case " $* " in
			*'change:reload(sleep 0.08;'*) ;;
			*) echo 'live search is not debounced' >&2; exit 2 ;;
		esac
	fi
	printf '%s\n' "$query"
	"${TEST_SCRIPT:?}" --search "${TEST_ROOT:?}" "$query" |
		awk -v wanted="${TEST_FZF_LINES:?}" '
			BEGIN { count = split(wanted, numbers, ","); for (i = 1; i <= count; i++) take[numbers[i]] = 1 }
			wanted == "all" || take[NR]
		'
	if [ -n "${TEST_MUTATE_PATH:-}" ]; then
		printf '%s\n' "${TEST_MUTATE_CONTENT:-changed}" >"$TEST_MUTATE_PATH"
	fi
	exit
fi

awk -v wanted="${TEST_FZF_LINES:?}" '
	BEGIN { count = split(wanted, numbers, ","); for (i = 1; i <= count; i++) take[numbers[i]] = 1 }
	wanted == "all" || take[NR]
'
EOF
chmod +x "$tmp/bin/fzf"

cat >"$tmp/bin/less" <<'EOF'
#!/bin/sh
for required in -R -F -X; do
	case " $* " in
		*" $required "*) ;;
		*) echo "missing less auto-paging option: $required" >&2; exit 2 ;;
	esac
done
if [ -n "${TEST_LESS_OUTPUT:-}" ]; then
	cat >"$TEST_LESS_OUTPUT"
else
	cat >/dev/null
fi
EOF
chmod +x "$tmp/bin/less"

run_replace() {
	PATH="$tmp/bin:$PATH" TEST_FZF_LINES=$1 TEST_SCRIPT="$script" TEST_ROOT="$tmp/project" \
		"$script" "$2" "$3" "$tmp/project" <<EOF
y
EOF
}

# Removing occurrence-level selection would replace all three instances and fail.
printf 'foo foo foo\n' >"$tmp/project/repeated.txt"
run_replace 2 foo BAR >/dev/null
[ "$(cat "$tmp/project/repeated.txt")" = 'foo BAR foo' ] || {
	echo 'not ok - selecting one occurrence changes only that occurrence' >&2
	exit 1
}
echo 'ok - selecting one occurrence changes only that occurrence'

# Losing the optional prefilled empty replacement would prompt or retain the text.
printf 'keep delete keep\n' >"$tmp/project/delete.txt"
run_replace 1 delete '' >/dev/null
[ "$(cat "$tmp/project/delete.txt")" = 'keep  keep' ] || {
	echo 'not ok - an explicitly empty replacement deletes the selected occurrence' >&2
	exit 1
}
echo 'ok - an explicitly empty replacement deletes the selected occurrence'

# Applying selected offsets from start to end would shift the second replacement.
printf 'x--x\n' >"$tmp/project/offsets.txt"
run_replace 1,2 x longer >/dev/null
[ "$(cat "$tmp/project/offsets.txt")" = 'longer--longer' ] || {
	echo 'not ok - multiple selected offsets are applied without position drift' >&2
	exit 1
}
echo 'ok - multiple selected offsets are applied without position drift'

# Treating UTF-8 arguments as already-decoded characters would corrupt validation/writeback.
printf '甲旧乙旧丙\n' >"$tmp/project/unicode.txt"
run_replace 2 旧 新 >/dev/null
[ "$(cat "$tmp/project/unicode.txt")" = '甲旧乙新丙' ] || {
	echo 'not ok - UTF-8 search and replacement stay byte-accurate' >&2
	exit 1
}
echo 'ok - UTF-8 search and replacement stay byte-accurate'

# A stray/invalid .git ancestor must not make the script run git diff.
printf 'a\n' >"$tmp/project/not-a-repo.txt"
messages=$(run_replace 1 a b 2>&1)
case $messages in
	*'Not a git repository'*|*'usage: git diff'*)
		echo 'not ok - invalid .git ancestors are ignored' >&2
		exit 1
		;;
esac
echo 'ok - invalid .git ancestors are ignored'

# Invoking without arguments searches live inside fzf, then prompts only for replacement.
printf 'zero prompt-old one\n' >"$tmp/project/no-arguments.txt"
(cd "$tmp/project" && PATH="$tmp/bin:$PATH" \
	TEST_REQUIRE_LIVE=1 TEST_INITIAL_QUERY='' TEST_FZF_QUERY=prompt-old \
	TEST_FZF_LINES=1 TEST_SCRIPT="$script" TEST_ROOT=. "$script" <<EOF >/dev/null
prompt-new
y
EOF
)
[ "$(cat "$tmp/project/no-arguments.txt")" = 'zero prompt-new one' ] || {
	echo 'not ok - no-argument mode prompts for both texts' >&2
	exit 1
}
echo 'ok - no-argument mode searches live and prompts for replacement'

# The query returned by fzf, not merely the initially-prefilled argument, defines the replacement.
printf 'actual actual\n' >"$tmp/project/edited-query.txt"
PATH="$tmp/bin:$PATH" TEST_REQUIRE_LIVE=1 TEST_INITIAL_QUERY=wrong \
	TEST_FZF_QUERY=actual TEST_FZF_LINES=1 TEST_SCRIPT="$script" TEST_ROOT="$tmp/project" \
	"$script" wrong changed "$tmp/project" <<EOF >/dev/null
y
EOF
[ "$(cat "$tmp/project/edited-query.txt")" = 'changed actual' ] || {
	echo 'not ok - edited fzf query becomes the exact replacement source' >&2
	exit 1
}
echo 'ok - edited fzf query becomes the exact replacement source'

# Dropping either binding would make the advertised select/deselect-all controls unavailable.
printf 'all all all\n' >"$tmp/project/select-all.txt"
PATH="$tmp/bin:$PATH" TEST_FZF_LINES=all TEST_REQUIRE_SELECT_ALL=1 \
	TEST_SCRIPT="$script" TEST_ROOT="$tmp/project" "$script" all every "$tmp/project" <<EOF >/dev/null
y
EOF
[ "$(cat "$tmp/project/select-all.txt")" = 'every every every' ] || {
	echo 'not ok - select-all applies every chosen occurrence' >&2
	exit 1
}
echo 'ok - select-all applies every chosen occurrence'

# Reading an already-decoded JSON string again breaks preview when metadata contains UTF-8.
printf '预览正文\n' >"$tmp/project/preview.txt"
printf '{"1":{"path":"%s","line":1,"text":"中文"}}\n' \
	"$tmp/project/preview.txt" >"$tmp/manifest.json"
preview=$($script --preview "$tmp/manifest.json" 1 2>&1) || {
	echo 'not ok - preview accepts UTF-8 metadata' >&2
	printf '%s\n' "$preview" >&2
	exit 1
}
case $preview in
	*'预览正文'*) ;;
	*) echo 'not ok - preview displays file context' >&2; exit 1 ;;
esac
echo 'ok - preview accepts UTF-8 metadata and displays context'

# Nearby selected matches should share one context block and show highlighted final text.
cat >"$tmp/project/merged-summary.txt" <<'EOF'
line one
merge-token first
middle
merge-token second
line five
line six
EOF
PATH="$tmp/bin:$PATH" TEST_FZF_LINES=all TEST_SCRIPT="$script" TEST_ROOT="$tmp/project" \
	TEST_LESS_OUTPUT="$tmp/summary.out" "$script" merge-token DONE "$tmp/project" <<EOF >/dev/null
y
EOF
plain_summary=$(perl -pe 's/\e\[[0-9;]*m//g' "$tmp/summary.out")
[ "$(printf '%s\n' "$plain_summary" | grep -c 'merged-summary.txt:')" -eq 1 ] || {
	echo 'not ok - nearby matches are merged into one summary block' >&2
	exit 1
}
case $plain_summary in
	*'DONE first'*'DONE second'*) ;;
	*) echo 'not ok - summary displays replacement text' >&2; exit 1 ;;
esac
LC_ALL=C grep -Fq "$(printf '\033')[1;32mDONE$(printf '\033')[0m" "$tmp/summary.out" || {
	echo 'not ok - replacement text is highlighted in summary' >&2
	exit 1
}
echo 'ok - nearby matches share a highlighted final-text summary block'

# A stale target in a later file must abort before an earlier file is written.
printf 'preflight-token first\n' >"$tmp/project/preflight-a.txt"
printf 'preflight-token second\n' >"$tmp/project/preflight-z.txt"
if PATH="$tmp/bin:$PATH" TEST_FZF_LINES=all TEST_SCRIPT="$script" TEST_ROOT="$tmp/project" \
	TEST_MUTATE_PATH="$tmp/project/preflight-z.txt" TEST_MUTATE_CONTENT='changed elsewhere' \
	"$script" preflight-token replaced "$tmp/project" <<EOF >/dev/null 2>&1
y
EOF
then
	echo 'not ok - stale selections abort the operation' >&2
	exit 1
fi
[ "$(cat "$tmp/project/preflight-a.txt")" = 'preflight-token first' ] || {
	echo 'not ok - full preflight prevents partial multi-file writes' >&2
	exit 1
}
echo 'ok - full preflight prevents partial multi-file writes'
