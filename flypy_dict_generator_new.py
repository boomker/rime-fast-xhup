#!/usr/local/bin/python3.11

import sys
from pathlib import PosixPath as pp
from functools import lru_cache
# from pypinyin import lazy_pinyin
# from datetime import date


def pinyin_to_flypy(pinyin: list[str]):
    @lru_cache(maxsize=None, typed=True)
    def to_flypy(pinyin: str):
        shengmu_dict = {"zh": "v", "ch": "i", "sh": "u"}
        yunmu_dict = {
            "ou": "z",
            "iao": "n",
            "uang": "l",
            "iang": "l",
            "en": "f",
            "eng": "g",
            "ang": "h",
            "an": "j",
            "ao": "c",
            "ai": "d",
            "ian": "m",
            "in": "b",
            "uo": "o",
            "un": "y",
            "iu": "q",
            "uan": "r",
            "iong": "s",
            "ong": "s",
            "ue": "t",
            "ve": "t",
            "ui": "v",
            "ua": "x",
            "ia": "x",
            "ie": "p",
            "uai": "k",
            "ing": "k",
            "ei": "w",
        }
        zero = {
            "a": "aa",
            "an": "an",
            "ai": "ai",
            "ang": "ah",
            "o": "oo",
            "ou": "ou",
            "e": "ee",
            "n": "en",
            "en": "en",
            "eng": "eg",
        }
        if pinyin in zero.keys():
            return zero[pinyin]
        else:
            if pinyin[1] == "h":
                shengmu = shengmu_dict[pinyin[:2]]
                yunmu = (
                    yunmu_dict[pinyin[2:]]
                    if pinyin[2:] in yunmu_dict.keys()
                    else pinyin[2:]
                )
                return shengmu + yunmu
            else:
                shengmu = pinyin[:1]
                yunmu = (
                    yunmu_dict[pinyin[1:]]
                    if pinyin[1:] in yunmu_dict.keys()
                    else pinyin[1:]
                )
                return shengmu + yunmu

    return [to_flypy(x) for x in pinyin]


def quanpin_to_flypy(line_content, *args):
    contents_perline = line_content.strip().split()
    if args[0]:
        from pypinyin import lazy_pinyin

        _pys = lazy_pinyin(contents_perline[0])
        pinyin_list = [i for i in _pys if i.isascii() and i.isalpha()]
    else:
        pinyin_list = [i for i in contents_perline if i.isascii() and i.isalpha()]
    if pinyin_list:
        print("pinyin_list: ", pinyin_list)
        flypy_list = pinyin_to_flypy(pinyin_list)
        word_frequency = (
            f"\t{contents_perline[-1]}" if contents_perline[-1].isnumeric() else ""
        )
        xhup_str = " ".join(flypy_list)
        item = f"{contents_perline[0].strip()}\t{xhup_str}{word_frequency}\n"
        yield item


def write_date_to_file(data, outfile):
    from datetime import date

    outfile_name = outfile.split(".")[0]
    dict_header = f"""
        # Rime dictionary
        # encoding: utf-8
        ## Based on http://gerry.lamost.org/blog/?p=296003

        ---
        name: {outfile_name}
        version: {date.today()}
        sort: by_weight
        # use_preset_vocabulary: true  # 導入八股文字頻
        # max_phrase_length: 1         # 不生成詞彙
        ...
    """

    if outfile not in globals().keys():
        with open(outfile, "w") as odf:
            # odf.write(dict_header)
            odf.write("\n".join([c.lstrip() for c in dict_header.splitlines()]))
            odf.write("\n")
    else:
        with open(outfile, "a") as odf:
            odf.write(data)

    globals().update({outfile: True})


def open_dict_and_send_line(infile):
    with open(infile, "r") as df:
        for line in df:
            tl = any(
                [
                    line.startswith("#"),
                    line.startswith(" "),
                    line.startswith("\n"),
                    line.startswith("-"),
                    line.startswith("."),
                    line[0].islower(),
                ]
            )
            if not tl:
                yield line


def main():
    hanzi2pinyin = sys.argv[-1]
    option = None if hanzi2pinyin.endswith("yaml") else hanzi2pinyin

    pp_objs = [pp(sys.argv[i]) for i in range(1, len(sys.argv))]
    infile_names = [f for f in pp_objs if f.is_file()]
    outfile_names = [f"flypy_{f.name.split('.')[0]}.dict.yaml" for f in infile_names]
    print(infile_names, outfile_names, option)
    print(
        """当你只看到上的回显提示,脚本就结束了, 那么说明命令行参数出问题了.
          当词典文件没有附带拼音, 那么`option`需要设非空值"""
    )
    input_datas = [open_dict_and_send_line(infile) for infile in infile_names]

    for outfile, indata in zip(outfile_names, input_datas):
        for idata in indata:
            for odata in quanpin_to_flypy(idata, option):
                write_date_to_file(odata, outfile)


if __name__ == "__main__":
    main()
