#!/bin/bash
# set -x

LONGOPTIONS="input:,output:"
# Note the '' next to the -o flag. Getopt requires that the -o flag be left blank in case there are no short-form arguments.
PARSED=$(getopt -o '' -l $LONGOPTIONS -- "$@")
eval set -- "$PARSED"

current_dir="$(pwd)"
usage() {
    echo "Usage: $0 --input <input_file> --output <output_file>"
    echo "Example: $0 --input index.html --output result.html"
    exit 1
}

is_relative() {
    local path=$1
    if [[ "$path" == /* ]]; then
        return 1
    else
        return 0
    fi
}

# 字串匹配與裁剪規則(%: 從右邊算起, #: 從左邊算起)
# ${var%/*}	    刪除最短匹配的後綴	/home/user/file.txt	/home/user
# ${var%%/*}	刪除最長匹配的後綴	/home/user/file.txt	""（空字串，因為 / 已經是開頭）
# ${var%.*}	    刪除最短匹配的後綴（去副檔名）	report.tar.gz	report.tar

# ${var#*/}	    刪除最短匹配的前綴	/home/user/file.txt	home/user/file.txt
# ${var##*/}	刪除最長匹配的前綴	/home/user/file.txt	file.txt
# ${var##*.}	刪除最長匹配的前綴（取得副檔名）	report.tar.gz	gz

# bash cannot return string, use echo
recursive_html() {
    local file_name=$1
    local result=""

    while read -r lin; do
        # -o: Prints only the matched part (not the whole line).
        # -P: Enables Perl-compatible regex (needed for (?<=...)).
        # (?<=src="): Lookbehind(?<=); Ensures src=" is before the match.
        # [^"]*: Captures everything until the next " (end of value).
        content=$(echo "$lin" | grep -oP '(?<=<include src=")[^"]+(?=" />)')
        # -n: check whether content is empty
        if [[ -n "$content" ]]; then
            if is_relative "$content"; then
                dir_path="${file_name%/*}"
                abs_content="$dir_path/$content"
            else
                abs_content="$content"
            fi

            if [[ "$abs_content" == *.html ]]; then
                included_content=$(recursive_html "$abs_content")
                result+="$included_content\n"
            elif [[ "$abs_content" == *.jpg ]] || [[ "$abs_content" == *.png ]]; then
                extension="${abs_content##*.}"
                base64_content=$(base64 "$abs_content")
                included_content="<img src='data:image/$extension;base64,$base64_content' />"
                result+="$included_content\n"
            elif [[ "$abs_content" == *.txt ]]; then
                result+="<div>$(cat "$abs_content")</div>\n"
            # -f: check whether content is a file, -r: check whether the file can be read
            elif ! [[ -f "$abs_content" && -r "$abs_content" ]]; then
                result+="<p style='color:red;'>Cannot access $content</p>\n"
            fi
        else
            result+="$lin\n"
        fi
    done < "$file_name"

    echo "$result"
}


while true;
do
    case $1 in
    --input)
        input_file_path=$2
        # the option + the option value = 2
        shift 2
        ;;
    --output)
        output_file_path=$2
        shift 2
        ;;
    --)
        # the end of the options(usually just add)
        shift; break;;
    esac
done

# -z: check whether the iuputs are given
if  [[ -z "$input_file_path" || -z "$output_file_path" ]];
then
    echo "Error: Missing input or output file."
    usage
fi

if is_relative $input_file_path; then
    input_file_path="$current_dir/$input_file_path"
fi

# -e: check whether the file exists
if ! ([[ -e "$input_file_path" ]] && [[ "$input_file_path" == *.html ]] && [[ "$output_file_path" == *.html ]]); then
    echo "Error: Invalid input or output file!"
    exit 1
fi

# echo -e will turn /n to new line
output=$(recursive_html "$input_file_path")
echo -e "$output" > "$output_file_path"





