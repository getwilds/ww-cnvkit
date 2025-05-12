version 1.0

workflow cnvkit_analysis {
  meta {
    author: "Taylor Firman"
    email: "tfirman@fredhutch.org"
    description: "WDL workflow for copy number variant analysis using CNVkit"
    url: "https://github.com/getwilds/ww-cnvkit"
    outputs: {
      cnr_file: "Copy number ratio file containing raw copy number data for each target bin",
      cns_file: "Copy number segments file containing averaged log2 ratios of copy number across segments",
      scatter_plot: "Scatter plot visualization of copy number across the genome",
      diagram_plot: "Chromosome diagram showing copy number alterations",
      heatmap_plot: "Heatmap visualization of copy number alterations across the sample"
    }
  }

  parameter_meta {
    sample_id: "Unique identifier for the sample being analyzed"
    tumor_bam: "BAM file containing reads from the tumor sample"
    normal_bam: "BAM file containing reads from the normal sample (used as reference)"
    reference_fasta: "Reference genome in FASTA format"
    target_bed: "BED file defining targeted genomic regions for analysis (optional, will be auto-detected if not provided)"
    antitarget_bed: "BED file defining off-target genomic regions to use (optional, will be auto-detected if not provided)"
    reference_cnn: "Pre-built CNVkit reference file (.cnn) (optional, will be created from normal_bam if not provided)"
    method: "Sequencing method used to generate data: 'hybrid' (default, for hybrid capture), 'amplicon', or 'wgs'"
  }

  input {
    # Sample information
    String sample_id
    File tumor_bam
    File normal_bam

    # Reference files
    File reference_fasta
    File? target_bed
    File? antitarget_bed
    File? reference_cnn

    # Parameters
    String method = "hybrid"  # hybrid, amplicon, wgs
  }

  # If reference_cnn is not provided, we need to create one
  if (!defined(reference_cnn)) {
    call build_reference { input:
        normal_bam = normal_bam,
        reference_fasta = reference_fasta,
        target_bed = target_bed,
        antitarget_bed = antitarget_bed,
        method = method
    }
  }

  call batch_analysis { input:
      sample_id = sample_id,
      tumor_bam = tumor_bam,
      reference_fasta = reference_fasta,
      reference_cnn = select_first([reference_cnn, build_reference.reference_cnn]),
      target_bed = target_bed,
      antitarget_bed = antitarget_bed,
      method = method
  }

  call scatterp { input:
      cnr_file = batch_analysis.cnr_file,
      cns_file = batch_analysis.cns_file,
      sample_id = sample_id
  }

  call diagram { input:
      cnr_file = batch_analysis.cnr_file,
      sample_id = sample_id
  }

  call heatmap { input:
      cnr_file = batch_analysis.cnr_file,
      sample_id = sample_id
  }

  output {
    File cnr_file = batch_analysis.cnr_file
    File cns_file = batch_analysis.cns_file
    File scatter_plot = scatterp.scatter_plot
    File diagram_plot = diagram.diagram_plot
    File heatmap_plot = heatmap.heatmap_plot
  }
}

task build_reference {
  meta {
    description: "Task for building a CNVkit reference profile from normal samples."
    outputs: {
      reference_cnn: "CNVkit reference file (.cnn) created from the normal sample, used for copy number calling"
    }
  }

  parameter_meta {
    normal_bam: "BAM file containing reads from the normal sample"
    reference_fasta: "Reference genome in FASTA format"
    target_bed: "BED file defining targeted genomic regions (optional, will be auto-detected if not provided)"
    antitarget_bed: "BED file defining off-target genomic regions (optional, will be auto-detected if not provided)"
    method: "Sequencing method: 'hybrid' (default), 'amplicon', or 'wgs'"
    memory_gb: "Memory allocated for the task in GB"
    cpu: "Number of CPU cores allocated for the task"
  }

  input {
    File normal_bam
    File reference_fasta
    File? target_bed
    File? antitarget_bed
    String method = "hybrid"
    Int memory_gb = 8
    Int cpu = 4
  }

  command <<<
    set -eo pipefail
    
    # If target BED is not provided, autodetect from the BAM file
    if [ -z "~{target_bed}" ]; then
      cnvkit.py autobin "~{normal_bam}" -m "~{method}" -f "~{reference_fasta}" --annotate
      TARGET_BED="on-target-annotated.bed"
      ANTITARGET_BED="off-target.bed"
    else
      TARGET_BED="~{target_bed}"
      ANTITARGET_BED="~{antitarget_bed}"
    fi
    
    # Build the reference
    cnvkit.py batch "~{normal_bam}" \
      --normal \
      --fasta "~{reference_fasta}" \
      --targets $TARGET_BED \
      --antitargets $ANTITARGET_BED \
      --output-reference reference.cnn \
      --processes ~{cpu}
  >>>

  output {
    File reference_cnn = "reference.cnn"
  }

  runtime {
    docker: "getwilds/cnvkit:0.9.10"
    memory: "~{memory_gb} GB"
    cpu: cpu
  }
}

task batch_analysis {
  meta {
    description: "Task for running the main CNVkit analysis on tumor samples."
    outputs: {
      cnr_file: "Copy number ratio file containing log2 ratios for each target bin",
      cns_file: "Copy number segments file containing averaged log2 ratios across called segments"
    }
  }

  parameter_meta {
    tumor_bam: "BAM file containing reads from the tumor sample"
    reference_fasta: "Reference genome in FASTA format"
    reference_cnn: "CNVkit reference file (.cnn) created from normal samples"
    sample_id: "Unique identifier for the sample being analyzed"
    target_bed: "BED file defining targeted genomic regions (optional, will be auto-detected if not provided)"
    antitarget_bed: "BED file defining off-target genomic regions (optional, will be auto-detected if not provided)"
    method: "Sequencing method: 'hybrid' (default), 'amplicon', or 'wgs'"
    memory_gb: "Memory allocated for the task in GB"
    cpu: "Number of CPU cores allocated for the task"
  }

  input {
    File tumor_bam
    File reference_fasta
    File reference_cnn
    String sample_id
    File? target_bed
    File? antitarget_bed
    String method = "hybrid"
    Int memory_gb = 8
    Int cpu = 4
  }

  command <<<
    set -eo pipefail
    
    # If target BED is not provided, autodetect from the BAM file
    if [ -z "~{target_bed}" ]; then
      cnvkit.py autobin "~{tumor_bam}" -m "~{method}" -f "~{reference_fasta}" --annotate
      TARGET_BED="on-target-annotated.bed"
      ANTITARGET_BED="off-target.bed"
      TARGET_ARGS="-t $TARGET_BED -a $ANTITARGET_BED"
    elif [ -n "~{target_bed}" ] && [ -n "~{antitarget_bed}" ]; then
      TARGET_ARGS="-t ~{target_bed} -a ~{antitarget_bed}"
    else
      TARGET_ARGS=""
    fi
    
    # Run CNVkit batch analysis
    cnvkit.py batch "~{tumor_bam}" \
      -r "~{reference_cnn}" \
      -f "~{reference_fasta}" \
      $TARGET_ARGS \
      --processes ~{cpu} \
      --output-dir ./
    
    # Rename output files with sample ID
    mv ./*/*.cnr "~{sample_id}.cnr"
    mv ./*/*.cns "~{sample_id}.cns"
  >>>

  output {
    File cnr_file = "~{sample_id}.cnr"
    File cns_file = "~{sample_id}.cns"
  }

  runtime {
    docker: "getwilds/cnvkit:0.9.10"
    memory: "~{memory_gb} GB"
    cpu: cpu
  }
}

task scatterp {
  meta {
    description: "Task for generating a genome-wide scatter plot of copy number data."
    outputs: {
      scatter_plot: "PDF file containing a scatter plot of copy number data across the genome with segmentation"
    }
  }

  parameter_meta {
    cnr_file: "CNVkit copy number ratio file (.cnr) containing bin-level copy number data"
    cns_file: "CNVkit copy number segments file (.cns) containing segmented copy number data"
    sample_id: "Unique identifier for the sample, used in output file naming"
    memory_gb: "Memory allocated for the task in GB"
    cpu: "Number of CPU cores allocated for the task"
  }

  input {
    File cnr_file
    File cns_file
    String sample_id
    Int memory_gb = 4
    Int cpu = 1
  }

  command <<<
    set -eo pipefail
    
    # Generate scatter plot
    cnvkit.py scatter "~{cnr_file}" \
      -s "~{cns_file}" \
      -o "~{sample_id}_scatter.pdf"
  >>>

  output {
    File scatter_plot = "~{sample_id}_scatter.pdf"
  }

  runtime {
    docker: "getwilds/cnvkit:0.9.10"
    memory: "~{memory_gb} GB"
    cpu: cpu
  }
}

task diagram {
  meta {
    description: "Task for generating a chromosome diagram of copy number alterations."
    outputs: {
      diagram_plot: "PDF file containing a chromosome diagram with copy number alterations"
    }
  }

  parameter_meta {
    cnr_file: "CNVkit copy number ratio file (.cnr) containing bin-level copy number data"
    sample_id: "Unique identifier for the sample, used in output file naming"
    memory_gb: "Memory allocated for the task in GB"
    cpu: "Number of CPU cores allocated for the task"
  }

  input {
    File cnr_file
    String sample_id
    Int memory_gb = 4
    Int cpu = 1
  }

  command <<<
    set -eo pipefail
    
    # Generate diagram
    cnvkit.py diagram "~{cnr_file}" \
      -o "~{sample_id}_diagram.pdf"
  >>>

  output {
    File diagram_plot = "~{sample_id}_diagram.pdf"
  }

  runtime {
    docker: "getwilds/cnvkit:0.9.10"
    memory: "~{memory_gb} GB"
    cpu: cpu
  }
}

task heatmap {
  meta {
    description: "Task for generating a heatmap visualization of copy number alterations."
    outputs: {
      heatmap_plot: "PDF file containing a heatmap visualization of copy number data"
    }
  }

  parameter_meta {
    cnr_file: "CNVkit copy number ratio file (.cnr) containing bin-level copy number data"
    sample_id: "Unique identifier for the sample, used in output file naming"
    memory_gb: "Memory allocated for the task in GB"
    cpu: "Number of CPU cores allocated for the task"
  }

  input {
    File cnr_file
    String sample_id
    Int memory_gb = 4
    Int cpu = 1
  }

  command <<<
    set -eo pipefail
    
    # Generate heatmap
    cnvkit.py heatmap "~{cnr_file}" \
      -o "~{sample_id}_heatmap.pdf"
  >>>

  output {
    File heatmap_plot = "~{sample_id}_heatmap.pdf"
  }

  runtime {
    docker: "getwilds/cnvkit:0.9.10"
    memory: "~{memory_gb} GB"
    cpu: cpu
  }
}
