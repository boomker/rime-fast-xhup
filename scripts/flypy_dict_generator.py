#!/usr/local/bin/pypy3

"""
Description: "shuang pin dict generate tool"
Project: github.com/boomker/rime-flypy-xhfast
Author: gmboomker@gmail.com
Date: 2024-10-01 11:47:22
LastEditTime: 2024-10-01 11:47:22
LastEditors: boomker
"""

import argparse
from functools import lru_cache
from platform import system as systype

if systype() == "Windows":
    from pathlib import Path as pp
else:
    from pathlib import PosixPath as pp

from pypinyin import Style, lazy_pinyin
from pypinyin_dict.phrase_pinyin_data import cc_cedict, zdic_cibs, zdic_cybs
from pypinyin_dict.phrase_pinyin_data import pinyin as pp_py
from pypinyin_dict.pinyin_data import ktghz2013

# import itertools
# from flypy_chars_zhuyin_dict import single_char_dict
# from pypinyin import lazy_pinyin, load_single_dict
# load_single_dict(single_char_dict)
from xhxm_map import xhxm_dict

pp_py.load()
ktghz2013.load()
cc_cedict.load()
zdic_cibs.load()
zdic_cybs.load()

"""
usage: flypy_dict_generator.py [-h] [--style {q,s,xh,he,zr,zrm,j}]
                                   [--convert] [--shape] --input_files
                                   [INPUT_FILES ...]
                                   [--word_frequency WORD_FREQUENCY] [--mode]
                                   [--type | --out_files [OUT_FILES ...]]

shuang pin dict generator tool

options:
  -h, --help            show this help message and exit
  --style {q,s,xh,he,zr,zrm,j}, -s {q,s,xh,he,zr,zrm,j}
                        spec the style, quanpin, shuangpin, jianpin, etc
  --convert, -c         spec from chinese convert to pinyin style
  --shape, -x           spec the style of shape, hxm, zrm etc
  --input_files [INPUT_FILES ...], -i [INPUT_FILES ...]
                        additional yaml dict files to input
  --word_frequency WORD_FREQUENCY, -w WORD_FREQUENCY
                        sepc word_frequency
  --mode, -m            spec output mode for generate file, w[rite] or a[ppend].
  --type, -t            spec generate filetype for output, yaml or text.
  --out_files [OUT_FILES ...], -o [OUT_FILES ...]
                        spec generate filename for output.

example:
    python3 flypy_dict_generator.py -i a.dict.yaml
    python3 flypy_dict_generator.py -i b.txt -t txt
    python3 flypy_dict_generator.py -i ab.dict.yaml -c
    python3 flypy_dict_generator.py -i abc.dict.yaml -c -x -w 100
    python3 flypy_dict_generator.py -i c.dict.yaml d.dict.yaml -o nc.dict.yaml nd.dict.yaml -m
"""


"""
def converte_to_pinyin(chinese: str):
    pinyin_list = pinyin(chinese, heteronym=True)
    sl = [" ".join(i) for i in itertools.product(*pinyin_list)]
    if len(sl) > 3:
        return {"lazy_pinyin": lazy_pinyin(chinese)}
    else:
        pyl = [to_normal(j) for j in sl]
        return {"multi_tone": list(set(pyl))}
"""


def pinyin_to_flypy(quanpin: list[str]):
    """全拼拼音转为小鹤双拼码, 如果转自然码请自行替换双拼映射

    Args:
        quanpin: [str]

    Returns:
        [str]
    """

    @lru_cache(maxsize=None, typed=True)
    def to_flypy(pinyin_str: str):
        shengmu_dict = {"zh": "v", "ch": "i", "sh": "u"}
        yunmu_dict = {
            "ou": "z",
            "iao": "n",
            "uang": "l",
            "iang": "l",
            "en": "f",
            "eng": "g",
            "ng": "g",
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
            "ei": "ei",
            "er": "er",
            "ao": "ao",
        }
        # 错误 Pinyin 返回原始拼音串
        if len(pinyin_str) == 1 and pinyin_str not in zero:
            return ""
        if pinyin_str in zero:
            return zero[pinyin_str]
        if pinyin_str[1] == "h" and len(pinyin_str) > 2:
            shengmu = shengmu_dict[pinyin_str[:2]]
            yunmu = yunmu_dict[pinyin_str[2:]] if pinyin_str[2:] in yunmu_dict else pinyin_str[2:]
            return shengmu + yunmu
        else:
            shengmu = pinyin_str[:1]
            yunmu = yunmu_dict[pinyin_str[1:]] if pinyin_str[1:] in yunmu_dict else pinyin_str[1:]
            return f"{shengmu}{yunmu}"

    return [to_flypy(x) if x.isalpha() else x for x in quanpin]


def gen_dict_record(pinyin_list, perline_contents, *args):
    if not pinyin_list:
        return None

    pinyin_style, _, shape_type, word_freq, filetype = args
    print("pinyin_list: ", pinyin_list, word_freq)
    if pinyin_style in ["shuangpin", "xhup", "zrup"]:  # 转换全拼为小鹤双拼
        flypy_list = pinyin_to_flypy(pinyin_list)
        # zrmpy_list = pinyin_to_zrmpy(pinyin_list)
    else:
        flypy_list = pinyin_list  # 首字母简写 or 全拼

    if shape_type in ["hxm", "zrm"] and pinyin_style != "jianpin":  # 转换对应汉字的形码
        # words_xm_list = [zrxm_dict.get(m, "[") for m in perline_contents[0].strip()]
        words_xm_list = [xhxm_dict.get(m, "|") for m in perline_contents[0].strip()]
        shuangpin_list = ["|".join([y, x]) for y, x in zip(flypy_list, words_xm_list)]
        yxencode_str = " ".join(shuangpin_list)
    else:
        yxencode_str = " ".join(flypy_list) if pinyin_style != "jianpin" else "".join(flypy_list)

    if int(word_freq) > 1:  # 当指定文件为yaml 或词频大于1
        word_frequency = f"{word_freq}"
    elif filetype == "yaml":
        word_frequency = perline_contents[-1] if perline_contents[-1].isnumeric() else word_freq
    else:
        word_frequency = word_freq or ""

    return f"{perline_contents[0].strip()}\t{yxencode_str}\t{word_frequency}\n"


def parser_line_content(line_content, *args):
    perline_contents = line_content.strip().split("\t")
    if not perline_contents[0]:
        return None

    pinyin_style, need_convert = args[0], args[1]
    if need_convert:
        pinyin_list = lazy_pinyin(perline_contents[0])
    elif pinyin_style == "jianpin":
        pinyin_list = lazy_pinyin(perline_contents[0], style=Style.FIRST_LETTER)
    else:
        pinyin_list = perline_contents[1].split() if len(perline_contents) > 1 else None

    yield gen_dict_record(pinyin_list, perline_contents, *args)


def write_date_to_file(data, outfile, mode):
    from datetime import date

    if not isinstance(outfile, str):
        outfile_name = outfile.name.split(".")[0]
        outfile_suffix_name = outfile.name.split(".")[-1]
    else:
        outfile_name = outfile.split(".")[0]
        outfile_suffix_name = outfile.split(".")[-1]
        outfile = pp(outfile)

    dict_header = f"""
        # Rime dictionary
        # encoding: utf-8

        ---
        name: {outfile_name}
        version: {date.today()}
        sort: by_weight
        ...
    """

    if outfile_suffix_name == "txt":
        globals()[outfile_name] = True
    if not outfile.exists():
        mode = "w"

    if outfile_name in globals() or mode == "a":
        with open(outfile, "a") as odf:
            odf.write(data)
    else:
        with open(outfile, "w") as odf:
            odf.write("\n".join([c.lstrip() for c in dict_header.splitlines()]))
            odf.write("\n")
    globals()[outfile_name] = True


def open_dict_and_send_line(infile):
    from string import ascii_letters
    with open(infile, "r") as fd:
        for line in fd.readlines():
            conditions = any(
                [
                    line.startswith("#"),
                    line.startswith("-"),
                    line.startswith("."),
                    line.startswith(" "),
                    line.startswith("\n"),
                    line.startswith(tuple(ascii_letters)),
                ]
            )
            if not conditions:
                yield line


def get_cli_args():
    parser = argparse.ArgumentParser(description="shuang pin dict generate tool")
    outfile_group = parser.add_mutually_exclusive_group()
    parser.add_argument(
        "--style",
        "-s",
        help="spec the style, quanpin, shuangpin, jianpin, etc",
        default="s",
        choices=["s", "j", "q", "xh", "he", "zr"],
    )
    parser.add_argument(
        "--convert",
        "-c",
        action="store_true",
        dest="chinese_to_pinyin",
        help="spec from chinses convert to pinyin style",
        default=False,
    )
    parser.add_argument(
        "--shape",
        "-x",
        dest="shape_type",
        help="spec the style of shape, hxm, zrm etc",
        default=None,
        const="hxm",
        action="store_const",
        # choices=[None, "hxm", "zrm"],
    )
    parser.add_argument(
        "--input_files",
        "-i",
        nargs="*",
        required=True,
        help=("add yaml dict files to input"),
        type=pp,
        # type=argparse.FileType("r", encoding="UTF-8"),
    )
    parser.add_argument(
        "--word_frequency",
        "-w",
        default=1,
        help=("sepc word_frequency"),
        type=int,
        # const="1",
        # action="store_const",
    )
    parser.add_argument(
        "--mode",
        "-m",
        help=("spec output mode for generate file , w or a."),
        default="w",
        const="a",
        action="store_const",
        # choices=["w", "a"],
    )
    outfile_group.add_argument(
        "--type",
        "-t",
        help=("spec generate filetype for output , yaml or txt."),
        dest="outfile_type",
        default="yaml",
        const="txt",
        action="store_const",
        # choices=["yaml", "txt"],
    )
    outfile_group.add_argument(
        "--out_files",
        "-o",
        help=("spec generate filename for output."),
        default=None,
        nargs="*",
        type=pp,
    )
    args = parser.parse_args()

    outfile_names = []
    for f in args.input_files:
        if args.outfile_type == "yaml":
            outfile_names.append(f"flypy_{f.name.split('.')[0]}.dict.yaml")
        else:
            outfile_names.append(f"flypy_{f.name.split('.')[0]}.txt")
    args_dict = vars(args)
    args_dict["outfiles"] = outfile_names if not args.out_files else args.out_files
    return args_dict, parser


def check_cli_args():
    try:
        _, test_parse = get_cli_args()
    except ValueError as ve:
        print("参数异常: ", repr(ve).split(":")[0])
        exit()
    except FileNotFoundError as fnfe:
        print("输入文件参数异常: ", repr(fnfe).split(":")[0])
        exit()

    if not test_parse.parse_args().input_files:
        print(test_parse.print_help())
        print("你没有指定待处理的输入文件!!!")
        exit()
    if test_parse.parse_args().chinese_to_pinyin:
        from subprocess import run

        c = run(["python3", "-m", "pypinyin", "-V"], capture_output=True)
        if (not c.stdout) or (c.returncode != 0):
            print("python3 pypinyin module not installed! \n")
            print("pls exec `pip3 install pypinyin`\n")
            exit()


def main():
    check_cli_args()
    cli_args_dict, _p = get_cli_args()
    cli_args = _p.parse_args()

    pinyin_style_map = {
        "s": "shuangpin",
        "q": "quanpin",
        "j": "jianpin",
        "sp": "shuangpin",
        "up": "shuangpin",
        "qp": "quanpin",
        "jp": "jianpin",
        "xh": "xhup",
        "he": "xhup",
        "zr": "zrup",
    }
    infiles = cli_args.input_files
    outfiles = cli_args_dict["outfiles"]
    write_mode = cli_args.mode

    print(
        "\n",
        f"mode: {write_mode}\n",
        f"input_files: {infiles}\n",
        f"output_files: {outfiles}\n",
        f"style: {pinyin_style_map[cli_args.style]}\n",
        f"word_frequency: {cli_args.word_frequency}\n",
        f"generate_shape_type: {cli_args.shape_type}\n",
        f"converte_to_pinyin: {cli_args.chinese_to_pinyin}\n",
        """
        当你只看到上面的回显提示, 脚本就结束了, 可能有异常:
        要么源文件没有待转换的词条, 要么说明命令行参数出问题了,
        当源词典文件没有附带拼音, 那么需要命令行指定 `-c` 选项.\n
        """,
    )

    producter_datas = [
        (outfile, open_dict_and_send_line(infile)) for infile, outfile in zip(infiles, outfiles)
    ]

    for outfile, yield_datas in producter_datas:
        for indata in yield_datas:
            if not indata:
                print("源文件内容格式错误, 正确格式: 汉字词条<Tab>pin yin(可选)<Tab>1(可选)")
                continue
            for data in parser_line_content(
                indata,
                pinyin_style_map[cli_args.style],
                cli_args.chinese_to_pinyin,
                cli_args.shape_type,
                cli_args.word_frequency,
                cli_args.outfile_type,
            ):
                if data:
                    write_date_to_file(data, outfile, write_mode)


if __name__ == "__main__":
    main()
