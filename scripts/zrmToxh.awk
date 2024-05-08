#!/usr/local/bin/gawk -f

# gawk -F'\t' -vOFS='\t' -f zrmToxh.awk s.dict.yaml > t.dict.yaml

{
     split($2, arr, " ")
     {
         for(i in arr) {
             if(arr[i] ~ /[a-z]k/) {
                 arr[i]=substr(arr[i],1,1)"c"
             } else if (arr[i] ~ /[a-z]w/) {
                 arr[i]=substr(arr[i],1,1)"x"
             } else if (arr[i] ~ /[a-z]y/) {
                 arr[i]=substr(arr[i],1,1)"k"
             } else if (arr[i] ~ /[a-z]p/) {
                 arr[i]=substr(arr[i],1,1)"y"
             } else if (arr[i] ~ /[a-z]d/) {
                 arr[i]=substr(arr[i],1,1)"l"
             } else if (arr[i] ~ /[a-z]l/) {
                 arr[i]=substr(arr[i],1,1)"d"
             } else if (arr[i] ~ /[a-z]z/) {
                 arr[i]=substr(arr[i],1,1)"w"
             } else if (arr[i] ~ /[a-z]x/) {
                 arr[i]=substr(arr[i],1,1)"p"
             } else if (arr[i] ~ /[a-z]b/) {
                 arr[i]=substr(arr[i],1,1)"z"
             } else if (arr[i] ~ /[a-z]c/) {
                 arr[i]=substr(arr[i],1,1)"n"
             } else if (arr[i] ~ /[^ae]n/) {
                 arr[i]=substr(arr[i],1,1)"b"
             }
         }
     }
     zm=""
     {for(j in arr){zm=zm?zm" "arr[j]:arr[j]}}
	 {if($4==""){print $1,zm,$3}else{print $1,zm,$3,$4}}
}
