# 单层遍历目录，保存所有文件路径到数组参数
# 目录不存在时返回空数组
#
# @param variable_name 保存文件路径的数组变量名，最好提前声明为空数组
# @param dir 要遍历的目录
# @param filter_callback 可选的过滤回调函数，返回非零值的文件将被忽略
function walk_dir() {
	local variable_name="$1" dir="$2" filter_callback="${3:-}" entries=() entry
	mapfile -d '' -t entries < <(find "$dir" -maxdepth 1 -mindepth 1 -type f -print0 | sort --zero-terminated) || true
	eval "$variable_name=()"
	for entry in "${entries[@]}"; do
		if [[ -z $entry ]]; then
			continue
		fi
		if [[ -n $filter_callback ]]; then
			"$filter_callback" "$entry" || continue
		fi
		eval "$(printf '%s+=(%q)' "$variable_name" "$entry")"
	done
}

function _filter_out_markdown() {
	[[ $1 != *.md ]]
}

# 执行bash脚本文件，提前加载这些函数库
function execute_script_file() {
	{
		printf "source %q\n" "${_loader_file}"
		printf "source %q\n" "${entry}"
	} | bash
}

# 调用目录中的多个脚本文件，忽略 Markdown 文件
function list_scripts_in_dir() {
	local var_name="$1" dir="$2"
	walk_dir "$var_name" "$dir" _filter_out_markdown
}

# 判断文件是否以换行符结尾
function file_ends_with_newline() {
	# https://stackoverflow.com/questions/38746/how-to-detect-file-ends-in-newline
	[[ $(tail -c1 "$1" | wc -l) -gt 0 ]]
}

# 确保文件以换行符结尾（或是空文件）
# 即确保它可以直接追加内容而不会破坏文件结构
# 如果文件不存在则创建空文件
function ensure_file_ends_with_newline() {
	local FILE="$1"
	if [[ -s $FILE ]]; then
		# 文件非空，检查是否以换行符结尾
		if ! file_ends_with_newline "$FILE"; then
			echo >>"$FILE"
		fi
	else
		mkdir -p "$(dirname "$FILE")"
		touch "$FILE"
	fi
}
