#!/usr/bin/env python

import sys, os, re
import pandas as pd

Trinotate_data = pd.read_csv("Trinotate_report.tsv", delimiter="\t")

eggnog_data = pd.read_csv(
    "eggnog_mapper.emapper.annotations", delimiter="\t", skiprows=4
)


eggnog_data.columns = ["EggNM." + x.replace("#", "") for x in list(eggnog_data.columns)]

eggnog_data = eggnog_data[~eggnog_data["EggNM.seed_ortholog"].isna()]

merged_data = pd.merge(
    Trinotate_data, eggnog_data, left_on="prot_id", right_on="EggNM.query", how="outer"
)

merged_data.to_csv(
    "Trinotate_and_EggnogMapper_report.tsv",
    sep="\t",
    na_rep=".",
    index=False,
)

sys.exit(0)
