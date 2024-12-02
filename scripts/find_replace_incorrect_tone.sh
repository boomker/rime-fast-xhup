#!/usr/local/bin/bash

function find_incorrect_tone() {
	[[ "$1" =~ '^[0-9]$' ]] && BASENAME="super_ext${1}" || BASENAME="${1}"
	mkdir -p "./tmp/${BASENAME}"
	while IFS= read -r line; do
		char=${line:0:1}
		charcode=${line:2:2}
		echo "$char" "$charcode"
		gawk -v CHAR="$char" -v CHARCODE="$charcode" -F'\t' 'NR>10 && $1 ~ CHAR {
    split($1, arr, 'x');split($2, s, " ");{
    for(i in arr){if(arr[i]==CHAR && s[i]!=CHARCODE)print $0}
    }}' "../cn_dicts/flypy_${BASENAME}.dict.yaml" >"./tmp/${BASENAME}/cyz-${char}_${charcode}"
	done <"./top3k_chars"
}

function replace_incorrect_tone() {
	[[ "$1" =~ '^[0-9]$' ]] && BASENAME="super_ext${1}" || BASENAME="${1}"
	touch ./tmp/chars_incorrect_${BASENAME}
	Pattern="**/${BASENAME}/cyz*"
	RepFileName="./tmp/chars_replaced_${BASENAME}.txt"
	fd -p -g "${Pattern}" --size -1b -X rm
	fd -p -g "${Pattern}" -t f -x gawk '{RC=substr(FILENAME, index(FILENAME, "-")+1);print RC"\t"$0}' {} >>"./tmp/chars_incorrect_${BASENAME}"
	gawk -F'\t' '{HZ=substr($1,0,1);CODE=substr($1,3);
    split($2, arra, 'x'); if(C[$2]){split(C[$2], arrb, " ")}else{split($3, arrb, " ")};
    for(i in arra){if(arra[i]==HZ && arrb[i]!=CODE) {arrb[i]=CODE}
    }; {for(j in arrb){zm=zm?zm" "arrb[j]:arrb[j]}
    }; {C[$2]=zm; D[$2]=$2"\t"zm"\t"$NF; zm=""}
    } END {for(d in D){print D[d]}}' "./tmp/chars_incorrect_${BASENAME}" >"${RepFileName}"
	hck -f1 "${RepFileName}" | xargs -I% ambr --no-interactive --no-parent-ignore --regex '^%\t.*' '' "../cn_dicts/flypy_${BASENAME}.dict.yaml"
	cat "${RepFileName}" >>"../cn_dicts/flypy_${BASENAME}.dict.yaml"
}

function main() {
	echo "${1}" "start ..."
	[[ $1 == "find" ]] && echo "find" && find_incorrect_tone $2
	[[ $1 == "rep" ]] && echo "rep" && replace_incorrect_tone $2
}

main $1 $2
