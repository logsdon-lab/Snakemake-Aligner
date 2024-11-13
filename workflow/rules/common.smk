import os
from collections import defaultdict
from typing import Iterator, DefaultDict


def read_fofn_file(path: str) -> Iterator[tuple[str, str]]:
    with open(path, "rt") as fh:
        for line in fh.readlines():
            abs_path = line.strip()
            base_path, fname = os.path.split(abs_path)
            fname = os.path.splitext(fname)[0]
            yield abs_path, fname


def get_dir_files(dirname: str, ext: str, depth: int = 1) -> Iterator[tuple[str, str]]:
    escaped_ext = re.escape(f".{ext}")
    path_pattern = re.compile(r"([^/]+)(" + escaped_ext + ")$")
    for i, (root, read_dirs, fnames) in enumerate(os.walk(dirname), 1):
        for file in fnames:
            read_dir_path = os.path.join(root, file)
            try:
                flowcell_id, _ = re.search(path_pattern, file).groups()
            except (ValueError, AttributeError):
                continue

            yield read_dir_path, flowcell_id

        if i == depth:
            break


def get_sample_assemblies_and_reads() -> (
    tuple[DefaultDict[str, dict[str, str]], DefaultDict[str, dict[str, str]]]
):
    SAMPLE_ASSEMBLIES = defaultdict(dict)
    SAMPLE_READS = defaultdict(dict)

    for sm in config["samples"]:
        sm_name = sm["name"]
        asm_fofn = sm.get("asm_fofn")
        read_fofn = sm.get("read_fofn")

        if asm_fofn:
            for file, fid in read_fofn_file(asm_fofn):
                SAMPLE_ASSEMBLIES[sm_name][fid] = file
        elif sm.get("asm_dir") and sm.get("asm_ext"):
            for file, fid in get_dir_files(sm["asm_dir"], sm["asm_ext"]):
                SAMPLE_ASSEMBLIES[sm_name][fid] = file
        elif sm.get("asm_fa"):
            SAMPLE_ASSEMBLIES[sm_name] = sm["asm_fa"]
        else:
            raise ValueError("Must provide either asm_fofn or asm_dir and asm_ext.")

        if read_fofn:
            for file, fid in read_fofn_file(read_fofn):
                SAMPLE_READS[sm_name][fid] = file
        elif sm.get("read_dir") and sm.get("read_ext"):
            for file, fid in get_dir_files(sm["read_dir"], sm["read_ext"]):
                SAMPLE_READS[sm_name][fid] = file
        else:
            raise ValueError("Must provide either read_fofn or read_dir and read_ext.")

    return SAMPLE_ASSEMBLIES, SAMPLE_READS
