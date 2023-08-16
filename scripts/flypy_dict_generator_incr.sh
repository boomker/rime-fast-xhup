#!/usr/local/bin/bash
set -eu

files=("base" "ext" "tencent" "emoji" "en_ext")
iceRepoPath="${HOME}/gitrepos/rime-ice"
repoRoot="$(git rev-parse --show-toplevel)"
scriptPath=$(dirname "$(realpath "$0")")
pyScrPath="${scriptPath}/flypy_dict_generator_new.py"
rimeUserPath="${HOME}/Library/Rime"
rimeDeployer="/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
git -C "${iceRepoPath}" pull

curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
[[ ${curCommit} == "${prevCommit}" ]] && exit

gcp -aR "${iceRepoPath}"/en_dicts/*.dict.yaml "${repoRoot}/en_dicts/"

for f in "${files[@]}";
do
    echo -e "\n----------\n" "$f"  "\n----------\n"
    src_file="${iceRepoPath}/cn_dicts/$f.dict.yaml"
    tgt_file="${repoRoot}/cn_dicts/flypy_${f}.dict.yaml"
    sorted_outfile="${repoRoot}/cn_dicts/flypy_${f}_sou.dict.yaml"
    [[ "$f" == "en_ext" ]] && src_file="${iceRepoPath}/en_dicts/en_ext.dict.yaml"
    [[ "$f" == "en_ext" ]] && tgt_file="${repoRoot}/en_dicts/en_ext.dict.yaml"
    [[ "$f" == "emoji" ]] && src_file="${iceRepoPath}/opencc/emoji.txt"
    [[ "$f" == "emoji" ]] && tgt_file="${repoRoot}/opencc/emoji_word.txt"

    git -C "${iceRepoPath}" diff "${prevCommit}"..HEAD -- "${src_file}" |\
        /usr/local/bin/rg  "^\-" |\rg -v "\-#|\+v|\---" |tr -d "-" > "${f}_min.diff"
    gcut -f1 "${f}_min.diff" |gxargs -I % -n 1 sd '^%\t.*' '' "${tgt_file}"
    gsed -i -r '14,${/^$/d}' "${tgt_file}"

    git -C "${iceRepoPath}" diff "${prevCommit}"..HEAD -- "${src_file}" |\
        /usr/local/bin/rg "^\+" |\rg -v "\+#|\+v|\+\+" |tr -d "+" > "${f}_add.diff"

    [[ "$f" =~ emoji|en_ext ]] && awk '{print $1"\t"$2,$3}' "${f}_add.diff" >> "${tgt_file}"
    [[ "$f" =~ emoji ]] && sort -u "${tgt_file}" -o tmp_emoji && mv tmp_emoji "${tgt_file}"
    if [[ $(wc -l "${f}_add.diff" |gcut -d ' ' -f -1) != 0 ]] && [[ ! $f =~ emoji|en_ext ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "ext" ]]; then
            pypy3 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m
        else
            pypy3 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m -c
        fi
    fi

    # git diff HEAD -- cn_dicts/flypy_ext.dict.yaml |rg "^\+" |rg -v "\+#|\+v|\+\+" |tr -d "+" > "cn-ext_add.diff"
    # awk -F'\t' '{s[$1]++;w[$0]}END{for(i in w){split(i, a, " ");if(s[a[1]]>1)print i}}' cn-ext_add.diff |sort
    rm "${f}_add.diff" "${f}_min.diff"
    [[ ! $f =~ emoji|en_ext ]] && {
        (head -13 "${tgt_file}"; gsed -n '14,$p' "${tgt_file}" |gsort -u) > "${sorted_outfile}"
        rm "${tgt_file}" && mv "${sorted_outfile}" "${tgt_file}"
    }
done


gcp -ar "${repoRoot}/cn_dicts"/* "${rimeUserPath}/cn_dicts/"
gcp -ar "${repoRoot}/en_dicts"/* "${rimeUserPath}/en_dicts/"
gcp -ar "${repoRoot}/opencc"/* "${rimeUserPath}/opencc/"
cd "${rimeUserPath}" && "${rimeDeployer}" --build > /dev/null && echo 'enjoy rime'
