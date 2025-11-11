#!/usr/local/bin/bash

function find_incorrect_tone() {
    [[ "$1" =~ '^[0-9]$' ]] && BASENAME="super_ext${1}" || BASENAME="${1}"
    mkdir -p "./tmp/${BASENAME}"
    while IFS= read -r line; do
        char=${line:0:1}
        charcode=${line:2:2}
        echo "$char" "$charcode"
        gawk -v CHAR="$char" -v CHARCODE="$charcode" -F'\t' 'NR>10 && $1 ~ CHAR {
            p=index($1, CHAR);
            if($1 ~ /CHAR.*CHAR.*/){l=length($1)}else{l=p};
            split($1, a, 'x');
            split($2, b, " ");
            for(i=p;i<=l;i++){
                if(a[i]==CHAR && b[i]!=CHARCODE){if(c!=$0){c=$0;print $0}}
            }
        }' "../cn_dicts/flypy_${BASENAME}.dict.yaml" >"./tmp/${BASENAME}/cyz-${char}_${charcode}"
    done <"./top4kchars"
}

function replace_incorrect_tone() {
    [[ "$1" =~ '^[0-9]$' ]] && BASENAME="super_ext${1}" || BASENAME="${1}"
    ErrRecFile="./tmp/chars_incorrect_${BASENAME}"
    RepRecFile="./tmp/chars_replaced_${BASENAME}"
    TargetDictFile="../cn_dicts/flypy_${BASENAME}.dict.yaml"
    Pattern="**/${BASENAME}/cyz*"
    touch ${ErrRecFile}
    fd --no-ignore-vcs -p -g "${Pattern}" --size -1b -X rm
    fd --no-ignore-vcs -p -g "${Pattern}" -t f -x \
        gawk '{RC=substr(FILENAME, index(FILENAME, "-")+1);print RC"\t"$0}' {} >>"${ErrRecFile}"
    gawk -F'\t' '{
        HZ=substr($1,1,1);
        CODE=substr($1,3);
        split($2, arra, 'x');
        if(C[$2]){split(C[$2], arrb, " ")}else{split($3, arrb, " ")};
        for(i in arra){
            if(arra[i]==HZ && arrb[i]!=CODE) {arrb[i]=CODE}
        }; for(j in arrb){
            zm=zm?zm" "arrb[j]:arrb[j]
        }; {C[$2]=zm; D[$2]=$2"\t"zm"\t"$NF; zm=""}
    } END {for(d in D){print D[d]}}' "${ErrRecFile}" >"${RepRecFile}"
    hck -f1 "${RepRecFile}" | xargs -I% ambr --no-interactive --no-parent-ignore --regex '^%\t.*' '' "${TargetDictFile}"
    cat "${RepRecFile}" >>"${TargetDictFile}"
}

function new_replace_incorrect_tone() {
    [[ "$1" =~ '^[0-9]$' ]] && BASENAME="super_ext${1}" || BASENAME="${1}"
    Pattern="**/${BASENAME}/cyz*"
    ErrRecFile="./tmp/chars_incorrect_${BASENAME}"
    RepRecFile="./tmp/chars_replaced_${BASENAME}"
    TargetDictFile="../cn_dicts/flypy_${BASENAME}.dict.yaml"
    touch "${ErrRecFile}"
    fd --no-ignore-vcs -p -g "${Pattern}" --size -1b -X rm
    fd --no-ignore-vcs -p -g "${Pattern}" -t f -x \
        zawk '{RC=substr(FILENAME, index(FILENAME, "-")+1);print RC"\t"$0}' {} >>"${ErrRecFile}"
    zawk -F'\t' '{
        AZ=chars($2);
        HZ=substr($1,1,1);
        CODE=substr($1,3);
        SP=index($2,HZ);
        EP=last_index($2,HZ);
        WL=(SP==EP)?SP:EP;
        WN=($NF ~ /^\d+$/)?$NF:100;
        if(C[$2]){split(C[$2], AC, " ")}else{split($3, AC, " ")};
        for(i=SP;i<=WL;i++){ if(AZ[i]==HZ && AC[i]!=CODE){ AC[i]=CODE } };
        for(j=1;j<=length(AC);j++){ CS=CS?CS" "AC[j]:AC[j] };
        {C[$2]=CS; D[$2]=$2"\t"CS"\t"WN; CS=""}
    } END {for(d in D){print D[d]}}' "${ErrRecFile}" >"${RepRecFile}"
    hck -f1 "${RepRecFile}" | xargs -I% ambr --no-interactive --no-parent-ignore --regex '^%\t.*' '' "${TargetDictFile}"
    cat "${RepRecFile}" >>"${TargetDictFile}"
}

function main() {
    echo "${1}" "start ..."
    [[ $1 == "find" ]] && echo "find" && find_incorrect_tone $2
    [[ $1 == "rep" ]] && echo "rep" && replace_incorrect_tone $2
}

main $1 $2

# function find_incorrect_tone() {
#     [[ "$1" =~ '^[0-9]$' ]] && BASENAME="super_ext${1}" || BASENAME="${1}"
#     mkdir -p "./tmp/${BASENAME}"
#     while IFS= read -r line; do
#         char=${line:0:1}
#         charcode=${line:2:2}
#         echo "$char" "$charcode"
#         zawk -v CHAR="$char" -v CHARCODE="$charcode" -F'\t' 'NR>10 && $1 ~ CHAR {
#             sp=index($1,CHAR);
#             ep=last_index($1,CHAR);
#             wl=(sp==ep)?sp:ep;
#             az=chars($1);
#             split($2, ac, " ");{
#                 for(i=sp;i<=wl;i++){
#                     if(az[i]==CHAR && ac[i]!=CHARCODE){if(R!=$0){R=$0;print $0}}
#                 }
#             }
#         }' "../cn_dicts/flypy_${BASENAME}.dict.yaml" >"./tmp/${BASENAME}/cyz-${char}_${charcode}"
#     done <"./top3k_chars"
# }
