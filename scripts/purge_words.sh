[[ "$(uname -s)" == Darwin ]] && SCMD="gsed" || SCMD="sed"
${SCMD} -i -e '/糖分手/d' \
	-e '/中国第金/d' \
	-e '/崔宸曦第/d' \
	-e '/泸上阿姨/d' \
	-e '/晚安安安/d' \
	-e '/积分夺宝卷/d' \
	-e 's/马楼/吗喽/1' \
	-e 's/吗楼/吗喽/1' \
	-e '/卡摸/s/摸/膜/1' \
	-e '/还我妈/s/hd/hr/1' \
	-e '/樊正东/s/正/振/1' \
	-e 's/孙银沙/孙颖莎/1' \
	-r -e '/^曾[^经几用]/s/\tcg/\tzg/1' cn_dicts/flypy_sogou.dict.yaml
