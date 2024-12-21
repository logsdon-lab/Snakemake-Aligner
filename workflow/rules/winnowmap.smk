ENV_YAML = f"../env/{ALIGNER}.yaml"


rule get_repetitive_kmers:
    input:
        asm=get_asm,
    output:
        kmer_cnts=directory(os.path.join(config["output_dir"], "{sm}_kmers")),
        filtered_kmer_cnts=os.path.join(config["output_dir"], "{sm}_kmers.txt"),
    params:
        kmers=15,
        distinct_perc=0.9998,
    conda:
        ENV_YAML
    log:
        os.path.join(LOGS_DIR, "winnowmap_get_repetitive_kmers_{sm}.log"),
    benchmark:
        os.path.join(BMKS_DIR, "winnowmap_get_repetitive_kmers_{sm}.tsv")
    shell:
        """
        meryl count k={params.kmers} output {output.kmer_cnts} {input.asm} 2> {log}
        meryl print greater-than distinct={params.distinct_perc} {output.kmer_cnts} > {output.filtered_kmer_cnts} 2>> {log}
        """


rule align_reads_to_asm:
    input:
        asm=get_asm,
        reads=lambda wc: SAMPLE_READS[str(wc.sm)][str(wc.id)],
        repetitive_kmers=rules.get_repetitive_kmers.output.filtered_kmer_cnts,
    output:
        temp(os.path.join(config["output_dir"], "{sm}_{id}_hifi.bam")),
    threads: config["threads_aln"]
    resources:
        mem=config["mem_aln"],
        sort_mem=4,
    params:
        aligner_opts=config.get("aligner_opts", "-a --eqx --cs -x map-pb"),
        reads=lambda wc, input: (
            f"<(samtools bam2fq -T '*' {input.reads})"
            if str(input.reads).endswith(".bam")
            else input.reads
        ),
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
        {{ winnowmap -W {input.repetitive_kmers} \
        {params.aligner_opts} \
        -t {threads} -I8g \
        {input.asm} {params.reads} | {params.samtools_view} \
        samtools sort -m {resources.sort_mem}G -@ {threads} - ;}} > {output} 2>> {log}
        """
