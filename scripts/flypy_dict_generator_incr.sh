#!/usr/local/bin/bash
set -eu

files=("base" "ext" "tencent" "emoji")
# iceRepoPath="${HOME}/gitrepos/rime-frost"
iceRepoPath="${HOME}/gitrepos/rime-ice"
repoRoot="$(git rev-parse --show-toplevel)"
scriptPath=$(dirname "$(realpath "$0")")
pyScrPath="${scriptPath}/flypy_dict_generator.py"
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
[[ -z $(git -C "${iceRepoPath}" status --short) ]] && git -C "${iceRepoPath}" pull
curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)

diffCommits="${prevCommit}..HEAD"
[[ ${curCommit} == "${prevCommit}" ]] && diffCommits="HEAD"
[[ -z $(git -C "${iceRepoPath}" status --short) ]] && [[ "${diffCommits}" == "HEAD" ]] && exit
gcp "${iceRepoPath}/en_dicts/en_ext.dict.yaml" "${repoRoot}/en_dicts/en_ext.dict.yaml"

for f in "${files[@]}"; do
    echo -e "\n----------\n" "$f" "\n----------\n"
    src_file="${iceRepoPath}/cn_dicts/$f.dict.yaml"
    tgt_file="${repoRoot}/cn_dicts/flypy_${f}.dict.yaml"
    sorted_outfile="${repoRoot}/cn_dicts/flypy_${f}_sou.dict.yaml"
    [[ "$f" == "emoji" ]] && src_file="${iceRepoPath}/opencc/emoji.txt"
    [[ "$f" == "emoji" ]] && tgt_file="${repoRoot}/opencc/emoji_word.txt"

    git -C "${iceRepoPath}" diff "${diffCommits}" -- "${src_file}" |
        /usr/local/bin/rg "^\-" | rg -v "\-#|\+v|\---" | tr -d "-" >"${f}_min.diff"
    gcut -f1 "${f}_min.diff" | xargs -I % -n 1 ambr --no-interactive --no-parent-ignore --regex '^%\t.*' '' "${tgt_file}"
    gsed -i -r '12,${/^$/d}' "${tgt_file}"

    git -C "${iceRepoPath}" diff "${diffCommits}" -- "${src_file}" |
        /usr/local/bin/rg "^\+" | rg -v "\+#|\+v|\+\+" | tr -d "+" >"${f}_add.diff"

    [[ "$f" =~ emoji ]] && awk '{print $1"\t"$2,$3}' "${f}_add.diff" >>"${tgt_file}"
    [[ "$f" =~ emoji ]] && sort -u "${tgt_file}" -o tmp_emoji && mv tmp_emoji "${tgt_file}"
    if [[ $(wc -l "${f}_add.diff" | gcut -d ' ' -f -1) != 0 ]] && [[ ! $f =~ emoji ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "ext" ]]; then
            python3 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m
            # pypy3 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m
        else
            python3 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m -c
            # pypy3 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m -c
        fi
    fi

    rm "${f}_add.diff" "${f}_min.diff"
    [[ ! $f =~ emoji ]] && {
        (
            head -9 "${tgt_file}"
            gsed -n '10,$p' "${tgt_file}" | gsort -u
        ) >"${sorted_outfile}"
        rm "${tgt_file}" && mv "${sorted_outfile}" "${tgt_file}"
    }
done
