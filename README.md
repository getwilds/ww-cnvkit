# ww-cnvkit
[![Project Status: Experimental – Useable, some support, not open to feedback, unstable API.](https://getwilds.org/badges/badges/experimental.svg)](https://getwilds.org/badges/#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A WILDS WDL workflow for detecting copy number variations (CNVs) using CNVkit.

## Overview

This workflow enables automated detection and visualization of copy number variations from targeted DNA sequencing data. It provides a complete pipeline that can:

- Work with hybrid capture, amplicon, and whole-genome sequencing data
- Create and use reference profiles
- Generate copy number ratio files, segmentation files, and visualizations
- Provide interactive visualization options including scatter plots, diagrams, and heatmaps

The workflow leverages CNVkit, a toolkit to infer and visualize copy number alterations from targeted DNA sequencing data, making it useful for cancer genomics and other applications that require CNV detection.

## Features

- Flexible reference handling: build a reference from normal samples or use a pre-built reference
- Support for multiple sequencing approaches: hybrid capture, amplicon, or WGS
- Automatic bin size calculation when target BEDs are not provided
- Parallelization for faster processing of large datasets
- Multiple visualization options: scatter plots, diagrams, and heatmaps
- Standardized output format compatible with downstream analysis

## Usage

### Requirements

- [Cromwell](https://cromwell.readthedocs.io/), [MiniWDL](https://github.com/chanzuckerberg/miniwdl), [Sprocket](https://sprocket.bio/), or another WDL-compatible workflow executor
- Docker/Apptainer (the workflow uses the `getwilds/cnvkit:0.9.10` container)

### Basic Usage

1. Create an inputs JSON file with your sample information:

```json
{
  "CNVKit.sample_id": "SAMPLE-001",
  "CNVKit.tumor_bam": "/path/to/tumor.bam",
  "CNVKit.normal_bam": "/path/to/normal.bam",
  "CNVKit.reference_fasta": "/path/to/reference.fa",
  "CNVKit.target_bed": "/path/to/targets.bed",
  "CNVKit.method": "hybrid",
  "CNVKit.diagram": true,
  "CNVKit.scatter": true,
  "CNVKit.heatmap": true
}
```

2. Run the workflow using your preferred WDL executor:

```bash
# Cromwell
java -jar cromwell.jar run ww-cnvkit.wdl --inputs ww-cnvkit-inputs.json

# miniWDL
miniwdl run ww-cnvkit.wdl -i ww-cnvkit-inputs.json

# Sprocket
sprocket run ww-cnvkit.wdl ww-cnvkit-inputs.json
```

### Detailed Options

The workflow accepts the following inputs:

| Parameter | Description | Type | Required? | Default |
|-----------|-------------|------|-----------|---------|
| `sample_id` | Identifier for the sample | String | Yes | - |
| `tumor_bam` | BAM file for the tumor/case sample | File | Yes | - |
| `normal_bam` | BAM file for the normal/control sample | File | No | - |
| `reference_fasta` | Reference genome in FASTA format | File | Yes | - |
| `target_bed` | BED file with targeted regions | File | No | - |
| `antitarget_bed` | BED file with antitarget regions | File | No | - |
| `reference_cnn` | Pre-built CNVkit reference file | File | No | - |
| `method` | Sequencing method: hybrid, amplicon, or wgs | String | No | "hybrid" |
| `diagram` | Generate diagram plot | Boolean | No | true |
| `scatter` | Generate scatter plot | Boolean | No | true |
| `heatmap` | Generate heatmap plot | Boolean | No | true |

### Output Files

The workflow produces the following outputs:

| Output | Description | Type |
|--------|-------------|------|
| `cnr_file` | Copy number ratio file | File |
| `cns_file` | Copy number segments file | File |
| `reference_cnn_out` | Reference file (if created) | File (optional) |
| `scatter_plot` | Scatter plot visualization | File (optional) |
| `diagram_plot` | Diagram visualization | File (optional) |
| `heatmap_plot` | Heatmap visualization | File (optional) |

## For Fred Hutch Users

For Fred Hutch users, we recommend using [PROOF](https://sciwiki.fredhutch.org/dasldemos/proof-how-to/) to submit this workflow directly to the on-premise HPC cluster. To do this:

1. Clone or download this repository
2. Update `ww-cnvkit-inputs.json` with your sample information
3. Update `ww-cnvkit-options.json` with your preferred output location (`final_workflow_outputs_dir`)
4. Submit the WDL file along with your custom JSONs to the Fred Hutch cluster via PROOF

### Example Options File

```json
{
    "workflow_failure_mode": "ContinueWhilePossible",
    "write_to_cache": true,
    "read_from_cache": true,
    "default_runtime_attributes": {
        "maxRetries": 1
    },
    "final_workflow_outputs_dir": "/your/output/path/",
    "use_relative_output_paths": true
}
```

## Advanced Usage

### Building a Reference from Normal Samples

If you have multiple normal samples, you can build a reference file outside this workflow and then use it as input:

```bash
cnvkit.py batch normal1.bam normal2.bam normal3.bam \
  --normal \
  --fasta reference.fa \
  --targets targets.bed \
  --output-reference reference.cnn
```

Then provide this reference in your inputs JSON:

```json
{
  "CNVKit.reference_cnn": "/path/to/reference.cnn",
  ...
}
```

### Handling Different Sequencing Methods

The workflow supports different sequencing methods by adjusting the `method` parameter:

- `hybrid`: For hybrid capture data (default)
- `amplicon`: For amplicon or targeted sequencing
- `wgs`: For whole-genome sequencing data

### Integrating with Other Workflows

This workflow is designed to be modular and can be easily integrated with other WILDS WDL workflows, such as alignment or variant calling pipelines. The output files are named with the sample ID for easy downstream processing.

## Support

For questions, bugs, and/or feature requests, reach out to the Fred Hutch Data Science Lab (DaSL) at wilds@fredhutch.org, or open an issue on our [issue tracker](https://github.com/getwilds/ww-cnvkit/issues).

## Contributing

If you would like to contribute to this WILDS WDL workflow, please see our [WILDS Contributor Guide](https://getwilds.org/guide/) for more details.

## License

Distributed under the MIT License. See `LICENSE` for details.
