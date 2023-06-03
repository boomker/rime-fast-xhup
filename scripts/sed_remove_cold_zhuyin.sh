# awk 'FNR>26 && NR==FNR{s[$1]=$0}{if(NR!=FNR && FNR>14 ){a[$1]++}}END{for(i in s)if(a[i]<1)print s[i]}' ext.dict.yaml flypy_ext.dict.yaml >jkl

gsed -i '/强/s/jiàng, //g' scripts/flypy_chars_zhuyin_dict.py

# gsed -i '/说/s/shuì, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(游|劝)]*说[^服]*uv/s/uv/uo/g' cn_dicts/flypy_ext.dict.yaml

# gsed -i '/奇/s/jī, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/奇[^(数|偶|计|记|集)]*ji/s/ji/qi/g' "$1" 2>/dev/null

# gsed -i '/校/s/jiào, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/校[^(准|对|补)]*jn/s/jn/xn/g' "$1" 2>/dev/null

# gsed -i '/了/s/, liǎo//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/了\t.*ln\t/s/ln\t/le\t/g' "$1" 2>/dev/null
gsed -i -r  '/[^聊|不]了[^(无|不起|得|解|望|当|事)]*ln[^(\t)]/d' "$1" 2>/dev/null 

gsed -i '/阿/s/, ē//g' scripts/flypy_chars_zhuyin_dict.py

# gsed -i '/没/s/, mò//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/^没[^(落|入|收)]*\tmo/s/mo/mw/g' "$1" 2>/dev/null
gsed -i -r '/[^(辱|吞|湮|隐|淹|沉|埋|鬼|覆|出)]没[^(落|莫|摸)]*mo/s/mo/mw/g' "$1" 2>/dev/null
gsed -i -r '/[^(辱|吞|湮|隐|淹|沉|埋|鬼|覆|出)]没[^(落|莫|摸)]*mo/d' "$1" 2>/dev/null 
gsed -i -r '/^没[^(落|入|收)]*\tmo/d' "$1" 2>/dev/null 

gsed -i '/曾/s/, zēng//g' scripts/flypy_chars_zhuyin_dict.py

# gsed -i '/都/s/, dū//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(首|大|魔|古|成|京|新|港|丽)]都.*du/s/du/dz/g' "$1" 2>/dev/null
gsed -i -r '/^都[^(城|市|护|伯|督)]*\tdu.*/s/du/dz/g' "$1" 2>/dev/null
gsed -i -r '/[^(首|大|魔|古|成|京|新|港|丽)]都.*du/d' "$1" 2>/dev/null
gsed -i -r '/^都[^(城|市|护|伯|督)]*\tdu.*/d' "$1" 2>/dev/null 

gsed -i '/车/s/, jū//g' scripts/flypy_chars_zhuyin_dict.py

# gsed -i '/会/s/, kuài//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i '/就会/s/jq kk/jq hv/g' "$1" 2>/dev/null
gsed -i -r '/会[^计]*kk\t/s/kk\t/hv\t/g' "$1" 2>/dev/null
gsed -i -r '/会[^计].*kk/d' "$1" 2>/dev/null

# gsed -i '/还/s/, huán//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/还没/s/hr mw/hd mw/g' "$1" 2>/dev/null
gsed -i -r '/还[^(钱|款|书|童|债|手|回|再借|珠|我|清|原)]*hr/d' "$1" 2>/dev/null

gsed -i '/艾/s/, yì//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/石/s/dàn, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/石.*dj/d' "$1" 2>/dev/null

gsed -i -r '/弹.*术/s/tj/dj/g' "$1" 2>/dev/null
gsed -i -r '/[^(子|炮|核|导)]弹[^(弓|坑)]*dj/d'  "$1" 2>/dev/null

gsed -i '/得/s/, děi//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/得[^(亏|看)]*dw/d' "$1" 2>/dev/null

gsed -i '/大/s/, dài//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r  '/大[^夫].*dd/d' "$1" 2>/dev/null

gsed -i '/行/s/héng, //g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/给/s/, jǐ//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^供]给[^(予|与)]*ji/d' "$1" 2>/dev/null
gsed -i -r '/^给.*\tji.*/d' "$1" 2>/dev/null

gsed -i '/呢/s/, ní//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/呢[^(喃|子|绒)]*ni\t/d' "$1" 2>/dev/null


gsed -i '/咋/s/, zé//g' scripts/flypy_chars_zhuyin_dict.py

# gsed -i '/卡/s/, qiǎ//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r  '/([^(发|哨|关)]卡|卡[^(住|壳|脖)]).*qx/s/qx/ka/g'  "$1" 2>/dev/null
gsed -i -r  '/([^(发|哨|关)]卡|卡[^(住|壳|脖)]).*qx/d' "$1" 2>/dev/null

gsed -i '/娜/s/, nuó//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i '/.*娜.*no/d' "$1" 2>/dev/null

gsed -i '/见/s/, xiàn//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(显|匕)]见[^先]*xm/d' "$1" 2>/dev/null

gsed -i '/叨/s/, tāo//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/核/s/, hú//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i '/核.*hu/d' "$1" 2>/dev/null

# gsed -i '/角/s/, jué//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(配|口|主|选)]角[^(逐|色|儿)].*jt/d' "$1" 2>/dev/null

# gsed -i '/吓/s/hè, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(恐|恫)]*吓.*he/d' "$1" 2>/dev/null

gsed -i -r '/便/s/, pián//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/便[^(宜|便)].*pm/d' "$1" 2>/dev/null

gsed -i -r '/期[^(年|月)]*ji/d' "$1" 2>/dev/null

gsed -i -r '/哦.*ee/d' "$1" 2>/dev/null

# gsed -i -r '/什/s/, shí//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/什么.*ui/s/ui m[w|e]/uf me/g' "$1" 2>/dev/null
gsed -i -r '/[^(是|布)]什[^(锦|尔|时)]*ui/d' "$1" 2>/dev/null
gsed -i -r '/^什[^(锦|尔|时)]*\tui/d' "$1" 2>/dev/null

gsed -i -r '/[(自|正|前|后|外|大|中|侠)]传.*ir/s/ir/vr/g' "$1" 2>/dev/null
gsed -i -r '/传[一|二|三|四|五|六|七|八|九|十]\t.*ir/s/ir/vr/g' "$1" 2>/dev/null
gsed -i -r '/^传.*\tvr/s/vr/ir/g' "$1" 2>/dev/null
gsed -i  '/不可外传/s/vr/ir/g' "$1" 2>/dev/null

gsed -i -r '/折/s/shé, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/折[^(本|耗)]*ue/d' "$1" 2>/dev/null 

gsed -i -r '/南.*na/d' "$1" 2>/dev/null

gsed -i -r '/[^(西|武|团|宝|三|青|地|雅鲁|川滇)]藏[^(民|族|区)]*zh/d' "$1" 2>/dev/null
gsed -i -r '/^藏.*\tzh/d' "$1" 2>/dev/null

gsed -i -r '/术.*vu/d' "$1" 2>/dev/null

gsed -i -r '/提/s/dī, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/提[^防]*di/d' "$1" 2>/dev/null

gsed -i -r '/地.*de/d' "$1" 2>/dev/null

gsed -i -r '/叶.*xp/d' "$1" 2>/dev/null

gsed -i -r '/区.*ou/d' "$1" 2>/dev/null

gsed -i -r '/抹/s/mā, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/抹[^布].*ma/d' "$1" 2>/dev/null

gsed -i -r '/[^(音|声|奏|礼|弦)]乐[^(队|理|团|章|器|毅)].*yt/d' "$1" 2>/dev/null

gsed -i -r '/万.*mo/d' "$1" 2>/dev/null

gsed -i -r '/无.*mo/d' "$1" 2>/dev/null

gsed -i -r '/[^(投|受|收)]降[^(服|龙|魔|祥)]*xl[^(\t)]/d' "$1" 2>/dev/null
gsed -i -r '/^降[^(服|龙|魔|祥)]*\txl/d' "$1" 2>/dev/null

gsed -i -r '/数.*uo/d' "$1" 2>/dev/null

gsed -i -r '/约.*yc/d' "$1" 2>/dev/null

gsed -i '/解/s/, xiè//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/解[^数]*xp/d' "$1" 2>/dev/null

gsed -i -r '/尾/s/, yǐ//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/尾.*yi/d' "$1" 2>/dev/null

gsed -i -r '/屏.*bk/d' "$1" 2>/dev/null

gsed -i -r  '/系.*[^(\t)]ji/s/ji/xi/g' "$1" 2>/dev/null
gsed -i -r  '/系.*[^(\t)]ji/d' "$1" 2>/dev/null

gsed -i -r '/度[^(步|势)]*do/d' "$1" 2>/dev/null

gsed -i -r '/洗/s/, xiǎn//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/洗.*xm/d' "$1" 2>/dev/null

gsed -i -r '/率[^(先|队)]*uk/s/uk/lv/g' "$1" 2>/dev/null
gsed -i -r '/率[^(先|队)]*uk/d' cn_dicts/flypy_ext.dict.yaml 

gsed -i -r '/[^(反|深)]*省[^(人事|亲)]*xk/s/xk/ug/g'  "$1" 2>/dev/null
gsed -i -r '/[^(反|深)]*省[^(人事|亲)]*xk/d' "$1" 2>/dev/null

gsed -i -r '/柜.*ju/d' "$1" 2>/dev/null

gsed -i -r '/[^保]炮.*bc/d' "$1" 2>/dev/null

gsed -i -r '/棱[^形]*lk/s/lk/lg/g' "$1" 2>/dev/null
gsed -i -r '/盛[^(饭|水|器)]*ig/s/ig/ug/g' "$1" 2>/dev/null

gsed -i -r '/[^(可|厌)]恶.*wu/s/wu/ee/g' "$1" 2>/dev/null
gsed -i -r '/[^(地|甲|躯)]壳.*qn/s/qn/ke/g' "$1" 2>/dev/null

# ------
awk -F'\t'  '{x=index($1, "和");split($2, a, " ");{if(a[x]=="hu")print $0}}' "$1" >dyzhu
awk -F'\t'  '{x=index($1, "和");split($2, a, " ");{if(a[x]=="ho")print $0}}' "$1" >dyzho
awk -F'\t'  '{x=index($1, "都");split($2, a, " ");{if(a[x]=="du")print $0}}' "$1" >dyzdu
awk -F'\t'  '{x=index($1, "说");split($2, a, " ");{if(a[x]=="uv")print $0}}' "$1" >dyzuv
awk -F'\t'  '{x=index($1, "没");split($2, a, " ");{if(a[x]=="mo")print $0"\t"NR}}' "$1" > dyzmo
awk -F'\t'  '{x=index($1, "还");split($2, a, " ");{if(a[x]=="hr")print $0"\t"NR}}' "$1" > dyzhr
