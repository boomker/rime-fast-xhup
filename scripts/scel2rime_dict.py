"""
搜狗细胞词库转鼠须管（Rime）词库

搜狗的 scel 词库是按照一定格式保存的 Unicode 编码文件，其中每两个字节表示一个字符（中文汉字或者英文字母），主要两部分:

1. 全局拼音表，在文件中的偏移值是 0x1540+4, 格式为 (py_idx, py_len, py_str)
    - py_idx: 两个字节的整数，代表这个拼音的索引
    - py_len: 两个字节的整数，拼音的字节长度
    - py_str: 当前的拼音，每个字符两个字节，总长 py_len

2. 汉语词组表，在文件中的偏移值是 0x2628 或 0x26c4, 格式为 (word_count, py_idx_count, py_idx_data, (word_len, word_str, ext_len, ext){word_count})，其中 (word_len, word, ext_len, ext){word_count} 一共重复 word_count 次, 表示拼音的相同的词一共有 word_count 个
    - word_count: 两个字节的整数，同音词数量
    - py_idx_count:  两个字节的整数，拼音的索引个数
    - py_idx_data: 两个字节表示一个整数，每个整数代表一个拼音的索引，拼音索引数
    - word_len:两个字节的整数，代表中文词组字节数长度
    - word_str: 汉语词组，每个中文汉字两个字节，总长度 word_len
    - ext_len: 两个字节的整数，可能代表扩展信息的长度，好像都是 10
    - ext: 扩展信息，一共 10 个字节，前两个字节是一个整数(不知道是不是词频)，后八个字节全是 0，ext_len 和 ext 一共 12 个字节

参考资料
1. https://raw.githubusercontent.com/archerhu/scel2mmseg/master/scel2mmseg.py
2. https://raw.githubusercontent.com/xwzhong/small-program/master/scel-to-txt/scel2txt.py
"""

import os
import struct
import sys
from datetime import datetime


def read_utf16_str(f, offset=-1, len=2):
    if offset >= 0:
        f.seek(offset)
    string = f.read(len)
    return string.decode("UTF-16LE")


def read_uint16(f):
    return struct.unpack("<H", f.read(2))[0]


def get_hz_offset(f):
    mask = f.read(128)[4]
    if mask == 0x44:
        return 0x2628
    elif mask == 0x45:
        return 0x26C4
    else:
        print("不支持的文件类型(无法获取汉语词组的偏移量)")
        sys.exit(1)


def get_dict_meta(f):
    title = read_utf16_str(f, 0x130, 0x338 - 0x130)
    category = read_utf16_str(f, 0x338, 0x540 - 0x338)
    desc = read_utf16_str(f, 0x540, 0xD40 - 0x540)
    samples = read_utf16_str(f, 0xD40, 0x1540 - 0xD40)
    return title, category, desc, samples


def get_py_map(f):
    py_map = {}
    f.seek(0x1540 + 4)

    while True:
        py_idx = read_uint16(f)
        py_len = read_uint16(f)
        py_str = read_utf16_str(f, -1, py_len)

        if py_idx not in py_map:
            py_map[py_idx] = py_str

        # 如果拼音为 zuo，说明是最后一个了
        if py_str == "zuo":
            break
    return py_map


def get_records(f, file_size, hz_offset, py_map):
    f.seek(hz_offset)
    records = []
    while f.tell() != file_size:
        word_count = read_uint16(f)
        py_idx_count = int(read_uint16(f) / 2)

        py_set = []
        for i in range(py_idx_count):
            py_idx = read_uint16(f)
            if not py_map.get(py_idx, None):
                return records
            py_set.append(py_map[py_idx])
        py_str = " ".join(py_set)

        for i in range(word_count):
            word_len = read_uint16(f)
            word_str = read_utf16_str(f, -1, word_len)

            # 跳过 ext_len 和 ext 共 12 个字节
            f.read(12)
            records.append((py_str, word_str))
    return records


def get_words_from_sogou_cell_dict(fname):
    with open(fname, "rb") as f:
        hz_offset = get_hz_offset(f)

        # (title, category, desc, samples) = get_dict_meta(f)
        py_map = get_py_map(f)

        file_size = os.path.getsize(fname)
        words = get_records(f, file_size, hz_offset, py_map)
        return words


def get_translated_record(records):
    records_translated = list(map(lambda x: "%s\t%s\t1" % (x[1], x[0]), records))
    return records_translated


def write_date_to_file(tgt_file, body_data):
    version_today = datetime.now().strftime("%Y.%m%d")
    dict_file_header = f"""
        # Rime dictionary
        # encoding: utf-8

        ---
        name: sougou_pop
        version: "{version_today}"
        sort: by_weight
        ...

    """

    header_data = "\n".join([c.lstrip() for c in dict_file_header.splitlines()])
    dict_merge_content = list(set(body_data))

    with open(tgt_file, "w") as dictfout:
        # 写入头部
        dictfout.write(header_data)
        # 写入合并后内容
        dictfout.write("\n".join(dict_merge_content))


def main():
    dict_merge_content = []
    scel_file = sys.argv[1] if len(sys.argv) > 1 else "./sougou_pop.scel"
    target_file = (
        sys.argv[2] if len(sys.argv) > 2 else "./cn_dicts/sougou_pop.dict.yaml"
    )

    if os.path.exists(target_file):
        os.remove(target_file)

    # if not os.path.exists("./scels"):
    #     os.mkdir(./scels)

    # # 将要转换的词库添加在 scel 目录下
    # scel_files = list(
    #     filter(lambda x: x.endswith(".scel"), [i for i in os.listdir(scels_dir)])
    # )
    # for scel_file in scel_files:
    try:
        # records = get_words_from_sogou_cell_dict(os.path.join(scels_dir, scel_file))
        records = get_words_from_sogou_cell_dict(scel_file)
        dict_merge_content.extend(get_translated_record(records))
    except Exception as e:
        print("词库 %s 转换失败，跳过该词库: %s" % (scel_file, e))
        os.exit()
    else:
        write_date_to_file(target_file, dict_merge_content)
    finally:
        os.remove(scel_file)


if __name__ == "__main__":
    main()
