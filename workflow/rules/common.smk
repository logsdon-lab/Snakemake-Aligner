import os
import hashlib
from collections import defaultdict
from typing import Iterator, NamedTuple


TMP_DIR = config.get("tmp_dir", os.environ.get("TMPDIR", "/tmp"))
LOGS_DIR = config.get("logs_dir", "logs/align")
BMKS_DIR = config.get("benchmarks_dir", "benchmarks/align")
ALIGNERS = {"winnowmap", "pbmm2", "minimap2"}
ALIGNER = config.get("aligner", "winnowmap")
ALL_MIN_READ_LENGTH = config.get("min_read_length")
ALL_KEEP_TAGS = config.get("keep_tags")


class Reads(NamedTuple):
    path: str
    min_read_length: int | None
    keep_tags: list[str] | None

    def is_bam(self) -> bool:
        return self.path.endswith("bam")

    def as_keep_tags_str(self) -> str:
        if not self.keep_tags:
            return "'*'"

        return ",".join(self.keep_tags)

    def as_cmd_arg(self) -> str:
        is_bam = self.is_bam()
        min_length = self.min_read_length
        reads = self.path
        if not min_length and not is_bam:
            return reads

        cmd = []
        if is_bam:
            keep_tags = self.as_keep_tags_str()
            cmd.extend(["samtools", "bam2fq", "-T", keep_tags, reads])

        if min_length and is_bam:
            cmd.extend(["|", "seqkit", "seq", "-m", str(min_length)])
        elif min_length:
            cmd.extend(["seqkit", "seq", "-m", str(min_length), reads])

        return f"<({' '.join(cmd)})"


def read_fofn_file(path: str) -> Iterator[tuple[str, str]]:
    with open(path, "rt") as fh:
        for line in fh.readlines():
            abs_path = line.strip()
            yield abs_path, hashlib.sha256(abs_path.encode()).hexdigest()


def get_dir_files(
    dirname: str, rgx: str, depth: int | None = None
) -> Iterator[tuple[str, str]]:
    path_pattern = re.compile(rgx)
    for i, (root, read_dirs, fnames) in enumerate(os.walk(dirname), 1):
        for file in fnames:
            read_dir_path = os.path.join(root, file)
            if not re.search(path_pattern, file):
                continue

            yield read_dir_path, hashlib.sha256(read_dir_path.encode()).hexdigest()

        if i == depth:
            break


def get_sample_assemblies_and_reads() -> (
    tuple[defaultdict[str, dict[str, str]], defaultdict[str, dict[str, Reads]]]
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
        elif sm.get("asm_dir") and sm.get("asm_rgx"):
            for file, fid in get_dir_files(sm["asm_dir"], sm["asm_rgx"]):
                SAMPLE_ASSEMBLIES[sm_name][fid] = file
        elif sm.get("asm_fa"):
            fid = hashlib.sha256(sm["asm_fa"].encode()).hexdigest()
            SAMPLE_ASSEMBLIES[sm_name][fid] = sm["asm_fa"]
        else:
            raise ValueError("Must provide either asm_fofn or asm_dir and asm_rgx.")

        if sm.get("reads"):
            for path in sm["reads"]:
                SAMPLE_READS[sm_name][
                    hashlib.sha256(path.encode()).hexdigest()
                ] = Reads(
                    path,
                    sm.get("min_read_length", ALL_MIN_READ_LENGTH),
                    sm.get("keep_tags", ALL_KEEP_TAGS),
                )
        elif read_fofn:
            for file, fid in read_fofn_file(read_fofn):
                SAMPLE_READS[sm_name][fid] = Reads(
                    file,
                    sm.get("min_read_length", ALL_MIN_READ_LENGTH),
                    sm.get("keep_tags", ALL_KEEP_TAGS),
                )
        elif sm.get("read_dir") and sm.get("read_rgx"):
            for file, fid in get_dir_files(sm["read_dir"], sm["read_rgx"]):
                SAMPLE_READS[sm_name][fid] = Reads(
                    file,
                    sm.get("min_read_length", ALL_MIN_READ_LENGTH),
                    sm.get("keep_tags", ALL_KEEP_TAGS),
                )
        else:
            raise ValueError(
                "Must provide either reads, read_fofn, or read_dir with read_rgx."
            )

    return SAMPLE_ASSEMBLIES, SAMPLE_READS
