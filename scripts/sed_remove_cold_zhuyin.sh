gsed -i '/强/s/jiàng, //g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/说/s/shuì, //g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/奇/s/jī, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/奇[^(数|偶)]*ji/d' "$1" 2>/dev/null

gsed -i '/校/s/jiào, //g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/了/s/, liǎo//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r  '/[^(了|知|少不)]*了[^(无|不起)]*ln/d' "$1" 2>/dev/null

gsed -i '/阿/s/, ē//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/没/s/, mò//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(淹|沉|埋|鬼)]没[^落]*mo/d' "$1" 2>/dev/null
gsed -i -r '/^没[^落]*\tmo/d' "$1" 2>/dev/null

gsed -i '/曾/s/, zēng//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/都/s/, dū//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(首|大|魔|古)]都[^城].*du/d' "$1" 2>/dev/null
gsed -i -r '/^都.*\tdu.*/d' "$1" 2>/dev/null

gsed -i '/车/s/, jū//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/会/s/, kuài//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^财]会[^计].*kk/d' "$1" 2>/dev/null
gsed -i -r '/^会.*\tkk.*/d' "$1" 2>/dev/null

gsed -i '/还/s/, huán//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/还[^(钱|款|书|童|债)]*hr/d' "$1" 2>/dev/null

gsed -i '/艾/s/, yì//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/石/s/dàn, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/石.*dj/d' "$1" 2>/dev/null

gsed -i '/得/s/, děi//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/得[^(亏|看)]*dw/d' "$1" 2>/dev/null

gsed -i '/大/s/, dài//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r  '/大[^夫].*dd/d' "$1" 2>/dev/null

gsed -i '/行/s/héng, //g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/给/s/, jǐ//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/呢/s/, ní//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/呢[^(喃|子|绒)]*ni\t/d' "$1" 2>/dev/null

gsed -i '/解/s/, xiè//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/咋/s/, zé//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/卡/s/, qiǎ//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r  '/([^(发|哨|关)]卡|卡[^(住|壳)]).*qx/d' "$1" 2>/dev/null

gsed -i '/娜/s/, nuó//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i '/.*娜.*no/d' "$1" 2>/dev/null

gsed -i '/见/s/, xiàn//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(显|匕)]见[^先]*xm/d' "$1" 2>/dev/null

gsed -i '/叨/s/, tāo//g' scripts/flypy_chars_zhuyin_dict.py

gsed -i '/核/s/, hú//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i '/核.*hu/d' "$1" 2>/dev/null

gsed -i '/角/s/, jué//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(配|口)]角[^(逐|色)].*jt/d' "$1" 2>/dev/null

gsed -i '/吓/s/hè, //g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/[^(恐|恫)]*吓.*he/d' "$1" 2>/dev/null

gsed -i -r '/便/s/, pián//g' scripts/flypy_chars_zhuyin_dict.py
gsed -i -r '/便[^宜].*pm/d' "$1" 2>/dev/null

gsed -i -r '/期[^(年|月)]*ji/d' "$1" 2>/dev/null
gsed -i -r '/哦.*ee/d' "$1" 2>/dev/null

gsed -i -r '/[^是]什[^(锦|尔|时)]*ui/d' "$1" 2>/dev/null
gsed -i -r '/^什[^(锦|尔|时)]*\tui/d' "$1" 2>/dev/null

gsed -i -r '/[^(自|正|前|后|外|侠)]传[^记].*vr[^(\t)]/d' "$1" 2>/dev/null
sei -r '/传[^说]*[^(\t)]ir/d' "$1" 2>/dev/null

gsed -i -r '/折.*ue/d' "$1" 2>/dev/null

gsed -i -r '/南.*na/d' "$1" 2>/dev/null

gsed -i -r '/[^(西|武|团)]藏[^(民|族)].*zh/d' "$1" 2>/dev/null
gsed -i -r '/^藏.*\tzh/d' "$1" 2>/dev/null

gsed -i -r '/术.*vu/d' "$1" 2>/dev/null

gsed -i -r '/提[^防]*di/d' "$1" 2>/dev/null

gsed -i -r '/地.*de/d' "$1" 2>/dev/null

gsed -i -r '/叶.*xp/d' "$1" 2>/dev/null

gsed -i -r '/区.*ou/d' "$1" 2>/dev/null

gsed -i -r '/[^供]给[^(予|与)]*ji/d' "$1" 2>/dev/null
gsed -i -r '/^给.*\tji.*/d' "$1" 2>/dev/null

gsed -i -r '/抹[^布].*ma/d' "$1" 2>/dev/null

gsed -i -r '/[^(音|声)]乐[^(队|理)].*yt/d' "$1" 2>/dev/null

gsed -i -r '/万.*mo/d' "$1" 2>/dev/null

gsed -i -r '/无.*mo/d' "$1" 2>/dev/null

gsed -i -r '/[^投]*降[^(服|龙)].*xl.*/d' "$1" 2>/dev/null

gsed -i -r '/数.*uo/d' "$1" 2>/dev/null

gsed -i -r '/约.*yc/d' "$1" 2>/dev/null

gsed -i -r '/解[^数]*xp/d' "$1" 2>/dev/null

gsed -i -r '/尾.*yi/d' "$1" 2>/dev/null

gsed -i -r '/屏.*bk/d' "$1" 2>/dev/null

gsed -i -r  '/系.*[^(\t)]ji/d' "$1" 2>/dev/null

gsed -i -r '/度[^步].*do/d' "$1" 2>/dev/null

sei -r '/[^子]弹[^弓].*dj/d' "$1" 2>/dev/null

sei -r '/洗.*xm/d' "$1" 2>/dev/null

sei -r '/率.*uk/d' "$1" 2>/dev/null

sei -r '/[^反]*省.*xk/d' "$1" 2>/dev/null
