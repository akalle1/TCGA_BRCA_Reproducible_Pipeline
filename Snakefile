
import pandas as pd

configfile: "config/config.yaml"

samples_df = pd.read_csv(config["samples"]["metadata"], sep="\t")
SAMPLES = samples_df["sample_id"].tolist()


rule all:
  input:
    #QC reports
    expand("results/qc/fastqc/{sample}_R1_fastqc.html", sample = SAMPLES),
    expand("results/qc/fastqc/{sample}_R2_fastqc.html", sample = SAMPLES),
    eresults/qc/fastqc/multiqc_report.html",
#how to make the product
    #salmon quantification
    #quants.sf- standard signature output file
    expand("results/salmon/{sample}/quant.sf", sample = SAMPLES),
    #Deseq2 results
    #main DESeq table
    #one row per gene- baseMean, log2Foldchange, lfcSe, stat, pvalue,padj
    "results/deseq2/differential_expression.csv",
    #normalized expression matrix- heatmaps, clustering, PC
    "results/deseq2/normalized_counts.csv"
    #Figures
    "results/figures/volcano_plot.pdf",
    "results/figures/pca_plot.pdf",
    "results/figures/heatmap.pdf"
#Reference preparation
rule download_transcriptome:
  output:
    "resources/references/gencode.v44.transcripts.fa.gz"
  params:
    url = "ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_44/gencode.v44.transcripts.fa.gz"
  shell:
    "wget -O {output} {params.url}"	


#Builds Salmon index directory from transcriptome FASTA
#Needed before Salmon can run
    # -t : transcriptome FASTA input
    # -i : output index directory
    # --gencode : parse headers as GENCODE format
    # -p : threads

rule salmon_index:
  input:
    transcriptome="resources/references/gencode.v44.transcripts.fa.gz"
  output:
    idx=directory("resources/salmon_index")
  conda:
    "envs/salmon.yaml"
  threads: 8
  log:
    "logs/salmon_index.log"
	shell:
	  """
	  salmon index \
	    -t {input.transcriptome} \
	    -i {output.idx} \
	    --gencode \
	    -p {threads} \
            > {log} 2>&1 
	  """
		
#quality control
#html report- *_fastqc.html
#zip bundle - _fatqc.zip
rule fastqc:
  input:
    "data/{sample}_{read}.fastq.gz"
  output:
    html="results/qc/fastqc/{sample}_{read}_fastqc.html"
    zip="results/qc/fastqc/{sample}_{read}_fastqc.zip"		
  conda:
    "envs/salmon.yaml"
  log:
    "logs/fastqc/{sample}_{read}.log"
  shell:
    """
    fastqc {input} -o results/qc/fastqc/ > {log} 2>&1
    """

rule multiqc:
  input:
    expand("results/qc/fastqc/{sample}_{read}_fastqc.zip",
       sample=SAMPLES, read=["R1","R2"])
  output:
    "results/qc/multiqc_report.html"
  conda:
    "envs/multiqc.yaml"
  log:
    "logs/multiqc.log"
  shell:
    """
    multiqc results/qc/fastqc/ -o results/qc/ > {log} 2>&1

    """
#salmon quantification
rule salmon_quant:
  input:
    r1 = "data/{sample}_R1.fastq.gz"
    r2 = "data/{sample}_R2.fastq.gz"
    index = "resources/salmon_index"
  output:
    quant = "results/salmon/{sample}/quant.sf",
    lib = "results/salmon/{sample}/lib_format_counts.json"    
  conda:
    "envs/salmon.yaml"
  threads: 4
  log: 
    "logs/salmon/{sample}.log"
  shell:
    """
    salmon quant \
    -i {input.index} \
    -l A \
    -1 {input.r1} \
    -2 {input.r2} \
    -o results/salmon/{wildcards.sample} \
    --validateMappings \
    --gcBias \
    --seqBias \
    -p {threads} \
    2> {log}
    """
#Differential Expression Analysis

rule create_txt2gene:
  input:
    gtf = "resources/annotations/gencode.v44.annotation.gtf.gz"
  output:
    "resources/annotations/tx2gene.tsv"
  conda:
    "envs/deseq2.yaml"
  script:
    "scripts/create_tx2gene.R"
#output
#differentila-expression.csv-main DE table
#normalized_counts.csv 
#object.RData- saves the DeSeq2 object- contains model fit, dispersions,results- PCA+heatmaps
rule deseq2:
  input:
    quants = expand("results/salmon/{sample}/quant.sf", sample=SAMPLES),
    samples = "config/samples.tsv",
    tx2gene = "resources/annotations/tx2gene.tsv"
  output:
    results="results/deseq2/differential_expression.csv",
    normalized="results/deseq2/normalized_counts.csv",
    rdata="results/deseq2/deseq2_object.RData"
  params:
    salmon_dir = "results/salmon", 
    alpha = config["deseq2"]["alpha"], #cutoffs for pvalues
    lfc_threshold = config["deseq2"]["lfc_threshold"] #minimum effect size thresholds
  conda:
    "envs/deseq2.yaml"
  log:
    "logs/deseq2_analysis.log"
  script:
    "scripts/run_deseq2.R"

  
rule pathway_enrichment:
  input:
    "results/deseq2/differential_expression.csv"
  output:
    go = "results/enrichment/go_enrichment.csv" #gene ration, pvalue/adjusted p-value, contributing genes
    kegg ="results/enrichment/kegg_enrichment.csv" #pathway name/ID, enrichment stats
  params:
    alpha=config["deseq2"]["alpha"],
    lfc_threshold=config["deseq2"]["lfc_threshold"]
  conda:
    "envs/deseq2.yaml"
  log:
    "logs/pathway_enrichment.log"
  script:
    "scripts/pathway_enrichment.R"

#visualization
rule create_figures: 
  input:
    deseq2_results = "results/deseq2/differential_expression.csv"
    deseq_object =  "results/deseq2/deseq2_object.RData"
  output:
    volcano = "results/figures/volcano_plot.pdf"
    pca = "results/figures/pca_plot.pdf"
    heatmap = "results/figures/heatmap.pdf"
  conda:
    "envs/deseq2.yaml"
  log:
    "logs/create_figures.log"
  script:
    "scripts/create_figures.R"

