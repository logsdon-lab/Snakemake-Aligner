ALIGNER_OPTS = config.get(
    "aligner_opts",
    # Equivalent alignment parameters to pbmm2
    # See https://github.com/PacificBiosciences/pbmm2?tab=readme-ov-file#what-are-parameter-sets-and-how-can-i-override-them
    # And https://lh3.github.io/minimap2/minimap2.html
    (
        "-y -a --eqx --cs -x map-hifi -I8g"
        if ALIGNER == "minimap2"
        else "--log-level DEBUG --preset SUBREAD --min-length 5000"
    ),
)
ENV_YAML = f"../env/{ALIGNER}.yaml"


rule align_reads_to_asm:
    input:
        asm=get_asm,
        reads=lambda wc: SAMPLE_READS[str(wc.sm)][str(wc.id)],
    output:
        temp(os.path.join(config["output_dir"], "{sm}_{id}_hifi.bam")),
    threads: config["threads_aln"]
    resources:
        mem=config["mem_aln"],
        sort_mem=4,
    params:
        aligner="minimap2" if ALIGNER == "minimap2" else "pbmm2 align",
        aligner_opts=ALIGNER_OPTS,
        reads=lambda wc, input: (
            f"<(samtools bam2fq -T {KEEP_TAGS} {input.reads})"
            if str(input.reads).endswith(".bam") and ALIGNER == "minimap2"
            else input.reads
        ),
        aligner_threads="-t" if ALIGNER == "minimap2" else "-j",
        samtools_view=(
            f"samtools view -F {config['samtools_view_flag']} -u - |"
            if config.get("samtools_view_flag")
            else ""
        ),
    shadow:
        "minimal"
    conda:
        ENV_YAML
    log:
        os.path.join(LOGS_DIR, "align_{sm}_{id}_hifi_reads_to_asm.log"),
    benchmark:
        os.path.join(BMKS_DIR, "align_{sm}_{id}_hifi_reads_to_asm.tsv")
    shell:
        """
        {{ {params.aligner} \
        {params.aligner_opts} \
        {params.aligner_threads} {threads} {input.asm} {params.reads} | {params.samtools_view} \
        samtools sort -m {resources.sort_mem}G -@ {threads} - ;}} > {output} 2>> {log}
        """
