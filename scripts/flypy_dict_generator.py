#!/usr/local/bin/pypy3

"""
Description: "shuang pin dict generate tool"
Project: github.com/boomker/rime-flypy-xhfast
Author: gmboomker@gmail.com
Date: 2023-04-14 11:47:22
LastEditTime: 2023-04-14 11:47:22
LastEditors: boomker
"""

import argparse
import itertools
from functools import lru_cache
from platform import system as systype

if systype() == "Windows":
    from pathlib import Path as pp
else:
    from pathlib import PosixPath as pp

from pypinyin import Style, lazy_pinyin, pinyin
from pypinyin.contrib.tone_convert import to_normal
from pypinyin_dict.phrase_pinyin_data import cc_cedict, zdic_cibs, zdic_cybs
from pypinyin_dict.phrase_pinyin_data import pinyin as pp_py
from pypinyin_dict.pinyin_data import ktghz2013

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
  --convert, -c         spec from hanzi convert to pinyin style
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
    python3 flypy_dict_generator.py -i bb.txt -t txt -w 0
    python3 flypy_dict_generator.py -i ab.dict.yaml -c
    python3 flypy_dict_generator.py -i abc.dict.yaml -c -x -w 100
    python3 flypy_dict_generator.py -i c.dict.yaml d.dict.yaml -o nc.dict.yaml nd.dict.yaml -m
"""


def pinyin_to_flypy(quanpin: list[str]):
    """全拼拼音转为小鹤双拼码, 如果转自然码请自行替换双拼映射

    Args:
        quanpin: [str]

    Returns:
        [str]
    """

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
        if len(pinyin) == 1 and pinyin not in zero:
            return ""
        if pinyin in zero:
            return zero[pinyin]
        if pinyin[1] == "h" and len(pinyin) > 2:
            shengmu = shengmu_dict[pinyin[:2]]
            yunmu = yunmu_dict[pinyin[2:]] if pinyin[2:] in yunmu_dict else pinyin[2:]
            return shengmu + yunmu
        else:
            shengmu = pinyin[:1]
            yunmu = yunmu_dict[pinyin[1:]] if pinyin[1:] in yunmu_dict else pinyin[1:]
            return f"{shengmu}{yunmu}"

    return [to_flypy(x) if x.isalpha() else x for x in quanpin]


def converte_to_pinyin(hanzi: str):
    pinyin_list = pinyin(hanzi, heteronym=True)
    sl = [" ".join(i) for i in itertools.product(*pinyin_list)]
    if len(sl) > 3:
        return {"lp": lazy_pinyin(hanzi)}
    npyl = []
    for j in sl:
        npy = to_normal(j)
        npyl.append(npy)
    spyl = list(set(npyl))
    return {"duoyinzi": spyl}


def gen_dict_record(pinyin_list, contents_perline, *args):
    if not pinyin_list:
        return
    print("pinyin_list: ", pinyin_list)
    if args[0] == "shuangpin":  # 转换全拼为小鹤双拼
        flypy_list = pinyin_to_flypy(pinyin_list)
    else:
        flypy_list = pinyin_list  # 首字母简写

    if args[2]:  # 转换对应汉字的形码
        words_xm_list = [xhxm_dict.get(m, "[") for m in contents_perline[0].strip()]
        xhup_list = ["[".join([e, x]) for e, x in zip(flypy_list, words_xm_list)]
        xhup_str = " ".join(xhup_list)
    else:
        xhup_str = " ".join(flypy_list) if args[0] != "jianpin" else "".join(flypy_list)

    if args[-1] == "yaml" or args[3] >= 1:  # 当指定文件为yaml 或词频大于1
        word_frequency = (
            f"\t{contents_perline[-1]}"
            if contents_perline[-1].isnumeric()
            else f"\t{args[3]}"
        )
    else:
        word_frequency = args[3] or ""

    return f"{contents_perline[0].strip()}\t{xhup_str}{word_frequency}\n"


def parser_line_content(line_content, *args):
    contents_perline = line_content.strip().split()
    if not len(contents_perline):
        return ""
    if args[0] and args[1]:  # 汉字转换对应风格的拼音
        if args[0] != "jianpin":
            _pyd = converte_to_pinyin(contents_perline[0])

            if list(_pyd.keys())[0] == "lp":
                _pys = list(_pyd.values())[0]
                pinyin_list = [i for i in _pys if i.isascii() and i.isalpha()]
                yield gen_dict_record(pinyin_list, contents_perline, *args)
            else:
                for i in list(_pyd.values())[0]:
                    _pyl = i.split()
                    pinyin_list = [i for i in _pyl if i.isascii() and i.isalpha()]
                    yield gen_dict_record(pinyin_list, contents_perline, *args)

        else:
            _pys = lazy_pinyin(contents_perline[0], style=Style.FIRST_LETTER)
            pinyin_list = [i for i in _pys if i.isascii() and i.isalpha()]
            yield gen_dict_record(pinyin_list, contents_perline, *args)
    else:
        pinyin_list = [
            i
            for i in contents_perline
            if (i.isascii() and i.isalpha()) or i.find("[") == 2
        ]
        yield gen_dict_record(pinyin_list, contents_perline, *args)


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
    with open(infile, "r") as fd:
        for line in fd.readlines():
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


def get_cli_args():
    parser = argparse.ArgumentParser(description="shuang pin dict generate tool")
    outfile_group = parser.add_mutually_exclusive_group()
    parser.add_argument(
        "--style",
        "-s",
        help="spec the style, quanpin, shuangpin, jianpin, etc",
        default="s",
        choices=["q", "s", "xh", "he", "zr", "zrm", "j"],
    )
    parser.add_argument(
        "--convert",
        "-c",
        action="store_true",
        dest="hanzi_to_pinyin",
        help="spec from hanzi convert to pinyin style",
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
        default="flypy",
        nargs="*",
        type=pp,
    )
    args = parser.parse_args()

    args_dict = vars(args)
    outfile_names = []
    for f in args.input_files:
        if args.outfile_type == "yaml":
            outfile_names.append(f"flypy_{f.name.split('.')[0]}.dict.yaml")
        else:
            outfile_names.append(f"flypy_{f.name.split('.')[0]}.txt")
    args_dict["out_files"] = args.out_files or outfile_names
    return args_dict, parser


def check_cli_args():
    try:
        _, test_parse = get_cli_args()
    except ValueError as ve:
        print("参数异常: ", repr(ve).split(":")[0], '")')
        exit()
    except FileNotFoundError as fnfe:
        print("输入文件参数异常: ", repr(fnfe).split(":")[0])
        exit()
    else:
        if not test_parse.parse_args().input_files:
            print(test_parse.print_help())
            print("你没有指定待处理的输入文件!!!")
            exit()
        if test_parse.parse_args().hanzi_to_pinyin:
            from subprocess import run

            c = run(["python3", "-m", "pypinyin", "-V"], capture_output=True)
            if not c.stdout and c.returncode:
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
        "qp": "quanpin",
        "jp": "jianpin",
        "xh": "xhup",
        "he": "xhup",
        "zr": "zrup",
        "zrm": "zrup",
    }
    infiles = cli_args.input_files
    outfiles = cli_args_dict["out_files"]
    # outfiles = cli_args.out_files
    write_mode = cli_args.mode

    print(
        f"mode: {write_mode}\n",
        f"input_files: {infiles}\n",
        f"output_files: {outfiles}\n",
        f"style: {pinyin_style_map[cli_args.style]}\n",
        f"word_frequency: {cli_args.word_frequency}\n",
        f"generate_shape_type: {cli_args.shape_type}\n",
        f"converte_to_pinyin: {cli_args.hanzi_to_pinyin}\n",
        """\n 当你只看到上的回显提示,脚本就结束了, 那么说明命令行参数出问题了.
        当词典文件没有附带拼音, 那么`-c` 需要指定 \n""",
    )

    # exit()
    input_datas = [open_dict_and_send_line(infile) for infile in infiles]

    for outfile, indata in zip(outfiles, input_datas):
        for idata in indata:
            for odata in parser_line_content(
                idata,
                pinyin_style_map[cli_args.style],
                cli_args.hanzi_to_pinyin,
                cli_args.shape_type,
                cli_args.word_frequency,
                cli_args.outfile_type,
            ):
                write_date_to_file(odata, outfile, write_mode)


if __name__ == "__main__":
    main()
