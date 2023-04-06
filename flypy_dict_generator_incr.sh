#!/usr/local/bin/bash

files=("base" "ext" "sogou" "tencent")
iceRepoPath="${HOME}/gitrepos/rime-ice"
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)

git -C "${iceRepoPath}" pull

curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
[[ ${curCommit} == "${prevCommit}" ]] && exit

for f in "${files[@]}";
do
    echo "$f"
    git diff prevCommit..HEAD -- "${iceRepoPath}/cn_dicts/$f.dict.yaml" |\rg  "^\+" |\rg -v "\+#|\+v|\+\+" |tr -d "+"  > "${f}.diff"
    if [[ $(wc -l "${f}.diff") != 0 ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "sogou" ]]; then
            python3.11 ./flypy_dict_generator_new.py "$f"
        else
            python3.11 ./flypy_dict_generator_new.py "$f" hanzhi
        fi
    fi

    sed -n '13,$p' "flypy_${f}.dict.yaml" >> "./cn_dicts/flypy_${f}.dict.yaml"
    rm "flypy_${f}.dict.yaml"
    rm "$f.diff"
done

