#!/usr/local/bin/bash

files=("base" "ext" "sogou" "tencent" "emoji")
iceRepoPath="${HOME}/gitrepos/rime-ice"
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# prevCommit="51461d7"
git -C "${iceRepoPath}" pull

curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# curCommit="272c706"
[[ ${curCommit} == "${prevCommit}" ]] && exit

for f in "${files[@]}";
do
    echo "\n----------\n" "$f"  "\n----------\n"
    src_file="${iceRepoPath}/cn_dicts/$f.dict.yaml"
    tgt_file="../cn_dicts/flypy_${f}.dict.yaml"
    [[ "$f" == "emoji" ]] && src_file="${iceRepoPath}/opencc/emoji.txt"
    [[ "$f" == "emoji" ]] && tgt_file="../opencc/emoji.txt"

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

    if [[ $(wc -l "${f}_add.diff" |cut -c 1) != 0 ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "sogou" ]]; then
            python3.11 ./flypy_dict_generator_new.py "${f}_add.diff"
        else
            python3.11 ./flypy_dict_generator_new.py "${f}_add.diff" hanzhi
        fi
    fi

    sed -n '13,$p' "flypy_${f}_add.dict.yaml" >> "${tgt_file}"
    rm "flypy_${f}_add.dict.yaml" "${f}_add.diff"
done

cp -ar "${iceRepoPath}/en_dicts/*.dict.yaml" "./en_dicts/"
sed -ir '/^[oz|oh|oq|oe|od]/Id' "./en_dicts/en.dict.yaml"

