#!/usr/local/bin/bash
set -eu

files=("base" "ext" "sogou" "tencent" "emoji")
iceRepoPath="${HOME}/gitrepos/rime-ice"
repoRoot="$(git rev-parse --show-toplevel)"
scriptPath=$(dirname "$(realpath "$0")")
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# prevCommit="51461d7"
git -C "${iceRepoPath}" pull

curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# curCommit="272c706"
[[ ${curCommit} == "${prevCommit}" ]] && exit

gcp -aR "${iceRepoPath}"/en_dicts/*.dict.yaml "${repoRoot}/en_dicts/"
gsed -i '/^[oz|oh|oq|oe|od]/Id' "${repoRoot}/en_dicts/en.dict.yaml"

for f in "${files[@]}";
do
    echo -e "\n----------\n" "$f"  "\n----------\n"
    src_file="${iceRepoPath}/cn_dicts/$f.dict.yaml"
    tgt_file="${repoRoot}/cn_dicts/flypy_${f}.dict.yaml"
    [[ "$f" == "emoji" ]] && src_file="${iceRepoPath}/opencc/emoji.txt"
    [[ "$f" == "emoji" ]] && tgt_file="{repoRoot}/opencc/emoji.txt"

    if [[ "$f" == "base" ]] || [[ "$f" == "emoji" ]]; then
        git -C "${iceRepoPath}" diff ${prevCommit}..HEAD -- "${src_file}" |\
            /usr/local/bin/rg  "^\-" |\rg -v "\-#|\+v|\---" |tr -d "-" > "${f}_min.diff"
        gcut -f1 "${f}_min.diff" |gxargs -I % -n 1 gsed -i  '/%/d' "${tgt_file}"
        rm "${f}_min.diff"
    fi
    git -C "${iceRepoPath}" diff ${prevCommit}..HEAD -- "${src_file}" |\
        /usr/local/bin/rg "^\+" |\rg -v "\+#|\+v|\+\+" |tr -d "+" > "${f}_add.diff"

    [[ "$f" == "emoji" ]] && {
        cat "${f}_add.diff" >> "${tgt_file}"
        rm "${f}_add.diff"
        exit
    }

    if [[ $(cat "${f}_add.diff" |wc -l |tr -d ' ') != 0 ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "sogou" ]]; then
            python3.11 "${scriptPath}/flypy_dict_generator_new.py" -i "${f}_add.diff" -o "${tgt_file}" -m
        else
            python3.11 "${scriptPath}/flypy_dict_generator_new.py" -i "${f}_add.diff" -o "${tgt_file}" -m -c
        fi
    fi

    [[ "${f}" == "base" ]] && {
        rg '^..\t.*'  "${f}_add.diff" > "${f}_twords.txt"
        python3.11 "${scriptPath}/flypy_dict_generator_new.py" -i "${f}_twords.txt" -c -x -m -o "${repoRoot}/cn_dicts/flypy_twords.dict.yaml"
        rm "${f}_twords.txt"
    }
    rm "${f}_add.diff"
done
