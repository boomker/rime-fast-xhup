#!/usr/local/bin/bash

files=("base" "ext" "sogou" "tencent")
iceRepoPath="${HOME}/gitrepos/rime-ice"
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# prevCommit="51461d7"
git -C "${iceRepoPath}" pull

curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# curCommit="272c706"
[[ ${curCommit} == "${prevCommit}" ]] && exit

for f in "${files[@]}";
do
    echo "$f"
    target_file="${iceRepoPath}/cn_dicts/$f.dict.yaml"
    git -C "${iceRepoPath}" diff ${prevCommit}..HEAD -- "${target_file}" |\rg  "^\+" |\rg -v "\+#|\+v|\+\+" |tr -d "+"  > "${f}.diff"
    if [[ $(wc -l "${f}.diff" |cut -c 1) != 0 ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "sogou" ]]; then
            python3.11 ./flypy_dict_generator_new.py "$f.diff"
        else
            python3.11 ./flypy_dict_generator_new.py "$f.diff" hanzhi
        fi
    fi

    sed -n '13,$p' "flypy_${f}.dict.yaml" >> "./cn_dicts/flypy_${f}.dict.yaml"
    rm "flypy_${f}.dict.yaml"
    rm "$f.diff"
done

