# Snakemake-Aligner
[![CI](https://github.com/logsdon-lab/Snakemake-Aligner/actions/workflows/main.yml/badge.svg)](https://github.com/logsdon-lab/Snakemake-Aligner/actions/workflows/main.yml)

A workflow to map long reads back to an assembly.

This workflow will:
1. Align reads via [`minimap2`](https://github.com/lh3/minimap2), [`pbmm2`](https://github.com/PacificBiosciences/pbmm2), or [`winnowmap`](https://github.com/marbl/Winnowmap).
2. Optionally, filter unmapped reads and non-primary alignments.

### Getting Started
```bash
git clone git@github.com:logsdon-lab/Snakemake-Aligner.git
cd Snakemake-Aligner
```

### Configuration

#### Input
Files can be passed multiple ways in the `samples` section of `config.yaml`:

##### Assemblies
By path.
```yaml
samples:
-   name: "1"
    asm_fa: "1.fa"
```

By `fofn`.
```yaml
samples:
-   name: "1"
    asm_fofn: "1.fofn"
```

By directory and file regex.
```yaml
samples:
-   name: "1"
    asm_dir: "1/"
    asm_rgx: ".*\\.fa.gz$"
```

##### Reads
By `fofn`.
```yaml
samples:
-   name: "1"
    read_fofn: "1.fofn"
```

By directory and file extension.
```yaml
samples:
-   name: "1"
    read_dir: "1/"
    read_rgx: ".*\\.bam$"
```

By path.
```yaml
samples:
-   name: "1"
    reads: [
        "1/r1.bam"
    ]
```

#### Configuration

##### General
General configuration can be filled in `config.yaml`:
```yaml
# Aligner to use.
# Either "winnowmap", "minimap2", or "pbmm2".
aligner: "winnowmap"
# To override default aligner params.
aligner_opts: "--MD -ax map-pb"
# Output directory
output_dir: "results/align"
# Log directory
logs_dir: "logs/align"
# Benchmarks directory
benchmarks_dir: "benchmarks/align"
# Job resources. Memory in GB.
threads_aln: 8
mem_aln: 30G
```

Aligner default parameters:
* `winnowmap`
    * `-y -a --eqx --cs -x map-pb -I8g`
* `pbmm2`
    * `--log-level DEBUG --preset SUBREAD --min-length 5000`
* `minimap2`
    * `-y -a --eqx --cs -x map-hifi -I8g`

To keep tags of BAM files:
```yaml
samples:
-   name: "1"
    keep_tags: ["ML", "MM"]

# Or globally across all samples:
keep_tags: ["ML", "MM"]
```

To keep reads greater than some length:
```yaml
samples:
-   name: "1"
    min_read_length: 30000

# Or globally across all samples:
min_read_length: 30000
```

To output CRAM files:
```yaml
output_format: cram
```

If output BAM files and need csi index.
```yaml
use_bam_csi: true
```

### Usage
```bash
snakemake -np -c 1 --configfile config/config.yaml
```

### Module
To incorporate this into a workflow.

```python
SAMPLE_NAMES = ["sample_1"]
CFG = {
    "samples": [
        {
            "name": sm,
            "asm_fa": f"{sm}.fa",
            "read_dir": f"reads/{sm}/",
            "read_ext": "bam",
        }
        for sm in SAMPLE_NAMES
    ],
    **config["align"]
}


module Align:
    snakefile:
        github(
            "logsdon-lab/Snakemake-Aligner",
            path="workflow/Snakefile",
            branch="main"
        )
    config: CFG

use rule * from Align as align_*

rule all:
    input:
        expand(rules.align.input, sm=SAMPLE_NAMES),
```

### Test
To run the dry-run workflow. Workflow with real files is a WIP.
```bash
snakemake --configfile test/config.yaml -c 1 -np
```
