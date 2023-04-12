#!/usr/local/bin/python3.11

# import sys
from pathlib import PosixPath as pp
from functools import lru_cache
from xhxm_map import xhxm_dict
import argparse

# from pypinyin import pinyin, lazy_pinyin, Style
# from datetime import date


def pinyin_to_flypy(quanpin: list[str]):
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
        if pinyin in zero:
            return zero[pinyin]
        if pinyin[1] == "h" and len(pinyin) > 2:
            shengmu = shengmu_dict[pinyin[:2]]
            yunmu = yunmu_dict[pinyin[2:]] if pinyin[2:] in yunmu_dict else pinyin[2:]
            return shengmu + yunmu
        else:
            shengmu = pinyin[:1]
            yunmu = yunmu_dict[pinyin[1:]] if pinyin[1:] in yunmu_dict else pinyin[1:]
            return shengmu + yunmu

    return [to_flypy(x) for x in quanpin]


def quanpin_to_flypy(line_content, *args):
    contents_perline = line_content.strip().split()
    if args[0] and args[1]:
        from pypinyin import lazy_pinyin, Style

        if args[0] != "jianpin":
            _pys = lazy_pinyin(contents_perline[0])
            pinyin_list = [i for i in _pys if i.isascii() and i.isalpha()]
        else:
            _pys = lazy_pinyin(contents_perline[0], style=Style.FIRST_LETTER)
            pinyin_list = [i for i in _pys if i.isascii() and i.isalpha()]
    else:
        pinyin_list = [i for i in contents_perline if i.isascii() and i.isalpha()]

    if pinyin_list:
        print("pinyin_list: ", pinyin_list)
        # print("xhxm_list: ", words_xm_list)
        if args[0] == "shuangpin":
            flypy_list = pinyin_to_flypy(pinyin_list)
        else:
            flypy_list = pinyin_list

        if args[2]:
            words_xm_list = [xhxm_dict.get(m, "[") for m in contents_perline[0].strip()]
            xhup_list = ["[".join([e, x]) for e, x in zip(flypy_list, words_xm_list)]
            xhup_str = " ".join(xhup_list)
        else:
            xhup_str = (
                " ".join(flypy_list) if args[0] != "jianpin" else "".join(flypy_list)
            )

        if args[-1] == "yaml":
            word_frequency = (
                f"\t{contents_perline[-1]}"
                if contents_perline[-1].isnumeric()
                else "\t1"
            )
        else:
            word_frequency = ""

        yield f"{contents_perline[0].strip()}\t{xhup_str}{word_frequency}\n"


def write_date_to_file(data, outfile):
    from datetime import date

    outfile_name = outfile.split(".")[0]
    outfile_suffix_name = outfile.split(".")[-1]
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

    if outfile_suffix_name == "txt":
        globals()[outfile] = True

    if outfile in globals():
        with open(outfile, "a") as odf:
            odf.write(data)
    else:
        with open(outfile, "w") as odf:
            # odf.write(dict_header)
            odf.write("\n".join([c.lstrip() for c in dict_header.splitlines()]))
            odf.write("\n")
    globals()[outfile] = True


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

def get_cli_args():
    parser = argparse.ArgumentParser(description="shuang pin dict generator tool")
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
        # action="append",
        # dest="input_files",
        help=("additional yaml dict files to input"),
        type=pp,
    )
    parser.add_argument(
        "--outfile_type",
        "-o",
        help=("spec generate FileType for output , yaml or text."),
        default="yaml",
        choices=["yaml", "txt"],
    )
    args = parser.parse_args()
    if args.hanzi_to_pinyin:
        from subprocess import run
        c = run(['python3', '-m', 'pypinyin', '-V'], capture_output=True)
        if not c.stdout and c.returncode:
            print('python3 pypinyin module not installed! \n')
            print('pls exec `pip3 install pypinyin`\n')
            exit()

    return parser.parse_args()


def main():

    cli_args = get_cli_args()

    pinyin_style_map = {
        "s": "shuangpin",
        "xh": "xhup",
        "he": "xhup",
        "zr": "zrup",
        "zrm": "zrup",
        "q": "quanpin",
        "j": "jianpin",
    }
    infiles = cli_args.input_files
    outfile_names = []
    for f in infiles:
        if cli_args.outfile_type == "yaml":
            outfile_names.append(f"flypy_{f.name.split('.')[0]}.dict.yaml")
        else:
            outfile_names.append(f"flypy_{f.name.split('.')[0]}.txt")

    print(
        infiles,
        outfile_names,
        pinyin_style_map[cli_args.style],
        cli_args.hanzi_to_pinyin,
        cli_args.shape_type,
        """\n 当你只看到上的回显提示,脚本就结束了, 那么说明命令行参数出问题了.
        当词典文件没有附带拼音, 那么`-c` 需要指定 \n""",
    )

    input_datas = [open_dict_and_send_line(infile) for infile in infiles]

    for outfile, indata in zip(outfile_names, input_datas):
        for idata in indata:
            for odata in quanpin_to_flypy(
                idata,
                pinyin_style_map[cli_args.style],
                cli_args.hanzi_to_pinyin,
                cli_args.shape_type,
                cli_args.outfile_type,
            ):
                write_date_to_file(odata, outfile)


if __name__ == "__main__":
    main()
