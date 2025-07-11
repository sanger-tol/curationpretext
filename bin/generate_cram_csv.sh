#!/bin/bash

set -euo pipefail

# generate_cram_csv.sh
# -------------------
# Generate a csv file describing the CRAM folder
# ><((((°>    Y    ><((((°>    U     ><((((°>    M     ><((((°>     I     ><((((°>
# Author = yy5
# ><((((°>    Y    ><((((°>    U     ><((((°>    M     ><((((°>     I     ><((((°>

# Function to process chunking of a CRAM file
chunk_cram() {
    local cram="$1"
    local chunkn="$2"
    local outcsv="$3"
    local realcram
    local realcrai
    realcram=$(readlink -f "$cram")
    realcrai=$(readlink -f "${cram}.crai")

    if [ ! -f "$realcrai" ]; then
        echo "Error: $realcrai does not exist" >&2
        exit 1
    fi

    local rgline
    rgline=$(samtools view -H "$realcram" | grep "@RG" | sed 's/\t/\\t/g' | tr -d "',")
    local ncontainers
    ncontainers=$(zcat "$realcrai" | wc -l)
    local base
    base=$(basename "$realcram" .cram)
    local from=0
    local to=10000

    while [ "$to" -lt "$ncontainers" ]; do
        echo "${realcram},${realcrai},${from},${to},${base},${chunkn},${rgline}" >> "$outcsv"
        from=$((to + 1))
        to=$((to + 10000))
        chunkn=$((chunkn + 1))
    done

    if [ "$from" -le "$ncontainers" ]; then
        echo "${realcram},${realcrai},${from},${ncontainers},${base},${chunkn},${rgline}" >> "$outcsv"
        chunkn=$((chunkn + 1))
    fi

    echo "$chunkn"
}

# Function to process a CRAM file
process_cram_file() {
    local cram="$1"
    local chunkn="$2"
    local outcsv="$3"

    local read_groups
    read_groups=$(samtools samples -T ID "$cram" | cut -f1)
    local num_read_groups
    num_read_groups=$(echo "$read_groups" | wc -w)

    echo "READ GROUPS FOUND IN $cram :$: $num_read_groups" >&2
    echo "READ GROUPS FOUND :$: $read_groups" >&2

    if [ "$num_read_groups" -gt 1 ]; then
        for rg in $read_groups; do
            echo "SPLITTING OUT READ GROUP $rg" >&2
            local output_cram
            output_cram="$(basename "${cram%.cram}")_output_${rg}.cram"
            samtools view -h -r "$rg" -o "$output_cram" "$cram"
            samtools index "$output_cram"
            chunkn=$(chunk_cram "$output_cram" "$chunkn" "$outcsv")
        done
    else
        chunkn=$(chunk_cram "$cram" "$chunkn" "$outcsv")
    fi

    echo "DATA :$: $chunkn" >&2
    echo "$chunkn"
}

# Main script to generate a CSV file describing the CRAM folder
#  /\_/\        /\_/\
# ( o.o ) main ( o.o )
#  > ^ <        > ^ <

# Check if cram_path is provided
if [ -z "${1:-}" ]; then
    echo "Usage: $0 <cram_path>" >&2
    exit 1
fi

cram_path="$1"
chunkn=0
outcsv="${2:-output.csv}"

# Loop through each CRAM file in the specified directory. cram cannot be the symlinked cram
for cram in "${cram_path}"/*.cram; do
    realcram=$(readlink -f "$cram")
    chunkn=$(process_cram_file "$realcram" "$chunkn" "$outcsv")
done
