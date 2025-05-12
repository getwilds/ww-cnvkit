version 1.0

workflow cnvkit_analysis {
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
