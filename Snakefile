rule all:
	input:
		"results/sample1_processed.txt"

#how to make the product

rule processed_data:
	input:
		"data/sample1.fastq"
	output:
		"results/sample1_processed.txt"
	shell:
		"cp {input} {output} && echo 'Processed by Snakemake' >> {output}"
