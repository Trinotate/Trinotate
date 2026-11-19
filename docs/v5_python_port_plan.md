# Trinotate v5: Python port — implementation plan

Status: **planned, not started** (written 2026-11-19, after the v4.0.4 release).
Owner/decision-maker: the Trinotate author (repo owner). Work is expected to be carried out
largely by coding agents; this document is the hand-off. Read it fully before starting.

---

## 1. Goal, motivation, and what "done" means

**Goal.** Re-implement Trinotate in Python as v5.0.0, replacing the Perl code base and the
legacy TrinotateWeb viewer, without breaking existing users.

**Motivation (settled, don't re-argue).** The reason is *maintainability and modern tooling*,
not speed. The Perl core works (v4.0.4 passes the full sample pipeline), and its runtime is
dominated by external tools (diamond/blast, hmmsearch, cmscan). Speed was measured: the one
real bottleneck (report generation on NFS) was fixed in Perl in 4.0.3 (35s → 1s) by reading
inside a single sqlite transaction. The stale part is **TrinotateWeb**: CGI scripts behind
lighttpd, ExtJS, and the CanvasXpress (Flash-era) plotting library. These are unmaintained and
hard to install. A Python code base also makes packaging (pip/bioconda) and contributions easier.

**Hard compatibility requirements.**
1. **Same CLI.** `Trinotate --db x.sqlite --create|--init|--run|--LOAD_*|--report ...`
   must accept the same flags and behave the same. Existing scripts and workflows must keep working.
2. **Same sqlite schema.** A v4 database must be readable/writable by v5 and vice versa
   (same table and column names, types, and semantics). No migrations in 5.0.
3. **Byte-identical report.** For the same database and options, `--report` output must be
   byte-identical to Perl v4.0.4. Same for `extract_GO_assignments_from_Trinotate_xls.pl`
   output and the report_summary stats (modulo the tie-ordering issue in §7).
4. **Same TRINOTATE_DATA_DIR layout** and checkpoint names, so an existing data dir built by
   v4 `--create` works with v5 without rebuilding.

**Done = v5.0.0 released** on GitHub, PyPI, bioconda and Docker Hub, with the golden
regression suite passing in CI, the new viewer shipped, and TrinotateWeb removed.

---

## 2. Decisions already made (with the user)

| Topic | Decision |
|---|---|
| Language | Python ≥ 3.9, stdlib `sqlite3` for DB access (no ORM). |
| Parity method | Golden-output regression tests captured from Perl v4.0.4 **before** porting anything (Phase 0). Python must match them. |
| Viewer | Replace TrinotateWeb with two commands: `trinotate report-html` (self-contained, offline single HTML file) and `trinotate view --db x.sqlite` (local FastAPI + Plotly server). No CGI, no lighttpd, no ExtJS, no CanvasXpress. |
| GTF/GFF3 genome-annotation mode | **Deferred.** `Gene_obj.pm` (5.6k lines) and `GTF.pm` (4.3k lines) back `--init` from a reference genome + GTF/GFF3 (`util/Trinotate_GTF_or_GFF3_annot_prep.pl`, `Trinotate_GTF_loader.pl`). Do not port these in 5.0. Keep the Perl scripts shipped and callable from the Python driver, or document the gap. Ask the user before dropping the feature. |
| CLI entry point | Keep the executable name `Trinotate` with the legacy flags. A lowercase `trinotate` alias with subcommands (`trinotate report-html`, `trinotate view`) may be added. The legacy flag form is the contract. |
| Packaging | pip (`pyproject.toml`) + bioconda (noarch python) + the existing Docker image. |

---

## 3. Current state of the code (v4.0.4, master)

Repo: `git@github.com:Trinotate/Trinotate.git` (push over SSH; see §8). About 24k lines of Perl.
About 10k of those are the deferred GTF/Gene_obj libraries.

### 3.1 Layout

```
Trinotate                       # driver (739 lines): CLI parsing, --create, --init, --run, --LOAD_*, --report
PerlLib/                        # libraries
  Sqlite_connect.pm             # DBI helpers + bulk_load_sqlite (sqlite3 CLI .import)
  Trinotate.pm                  # report-time queries: blast/pfam/go/eggnog/kegg lookups (538 lines)
  Pipeliner.pm                  # command runner with .ok checkpoint files
  DelimParser.pm, Fasta_reader.pm, Nuc_translator.pm, Longest_orf.pm, GO_DAG.pm, ...
  Gene_obj.pm, GTF.pm, GTF_utils.pm, GFF3_utils.pm     # deferred (genome-annotation mode)
util/
  Trinotate_report_writer.pl    # --report implementation (640 lines)
  trinotateSeqLoader/           # loaders: TrinotateSeqLoader.pl (--init), *_BLAST/PFAM/SIGNALP/TmHMMv2/DeepTmHMM/Infernal/RNAMMER/GTF_loader.pl
  admin/                        # --create: Build_Trinotate_Boilerplate_SQLite_db.pl + util/ parsers
    util/eggNOG5_og_annotations_parser.pl, EMBL_swissprot_parser.pl, PFAM_dat_parser.pl,
         EMBL_dat_to_Trinotate_sqlite_resourceDB.pl, init_Trinotate_sqlite_db.pl (schema DDL)
  annotation_importer/          # EggnogMapper loader etc.
  extract_GO_assignments_from_Trinotate_xls.pl
  report_summary/               # trinotate_report_summary.pl + make_cXp_html.pl (CanvasXpress HTML)
  transcript_expression/        # import expression matrices + DE results + clusters (TrinotateWeb inputs)
  gene_ontology/, functional_enrichment_analysis/, rnammer_support/ (legacy)
TrinotateWeb/, TrinotateWeb.conf, run_TrinotateWebserver.pl, __launch_TrinotateWeb_*.sh   # to be replaced
testing/                        # runMe.sh (full sample pipeline), runMe.add_expression_prep_TrinotateWeb.sh, input_data/*.gz
Docker/                         # Dockerfile, VERSION.txt, build/push/make_simg scripts
```

### 3.2 CLI modes (driver `Trinotate`)

- `--create --trinotate_data_dir DIR`. Builds `TrinotateBoilerplate.sqlite`: downloads SwissProt (EMBL dat),
  Pfam-A.hmm, GO obo, pfam2go and eggNOG v5 `e5.og_annotations.tsv`, then parses
  and bulk-loads them. Then: makeblastdb, diamond makedb, hmmpress, Rfam download + cmpress. Copies the
  boilerplate to the user's `--db`. Downloads eggnog-mapper data if `emapper.py` is present and
  `EGGNOG_DATA_DIR` is unset. Checkpoints go in `DIR/__chckpts/*.ok`, and the boilerplate build's own
  checkpoints go in `./__trino_chkpts`.
- `--init --gene_trans_map --transcript_fasta --transdecoder_pep` loads Transcript and ORF tables.
- `--run ALL | "swissprot_blastp swissprot_blastx pfam signalp6 tmhmmv2 infernal EggnogMapper"` with
  `--CPU`, `--use_diamond`, `--transcript_fasta`, `--transdecoder_pep`. Each tool is followed by a
  self-invocation `Trinotate --db X --LOAD_<type> <output>`. Checkpoints go in `./__trinotate_run_checkpts/`.
  Command lines are in `sub Trinotate_RUN_annotators` (the diamond/blast/hmmsearch/tmhmm/signalp6/cmscan/emapper invocations).
- `--LOAD_swissprot_blastp|blastx|pfam|signalp|tmhmmv2|deeptmhmm|infernal|EggnogMapper <file>`, and
  `--LOAD_custom_blast <file> --blast_type blastp|blastx --custom_db_name NAME`.
- `--report [-E 1e-5] [--pfam_cutoff DNC|DGC|DTC|SNC|SGC|STC] [--incl_pep] [--incl_trans]` writes the TSV to stdout.

### 3.3 sqlite schema

DDL is in `util/admin/util/init_Trinotate_sqlite_db.pl`, which is the authoritative source. Tables:
`UniprotIndex, PFAMreference, TaxonomyIndex, BlastDbase, HMMERDbase, SignalP, Transcript, ORF, tmhmm,
eggNOGIndex, go, go_slim, go_slim_mapping, pfam2go, Samples, Replicates, Expression, Diff_expression,
ExprClusterAnalyses, ExprClusters, RNAMMERdata, Infernal, EggnogMapper`.
Boilerplate scale: UniprotIndex ≈ 5.1M rows, eggNOGIndex ≈ 4.4M, go ≈ 48k. The full DB is about 700 MB.

### 3.4 External tools

diamond, blastp/blastx/makeblastdb (NCBI BLAST+), hmmsearch/hmmpress (HMMER 3), cmscan/cmpress
(Infernal), sqlite3 CLI, wget, gzip. Optional: emapper.py/download_eggnog_data.py (eggnog-mapper
≥ 2.1.14, which uses the new eggnog5.embl.de host), signalp6, tmhmm (v2), DeepTMHMM (run externally, then loaded).

---

## 4. Phased plan

Each phase ends with a commit or PR on a `v5` branch. Do not merge to master until Phase 7.
Check every phase against Phase 0's goldens before moving on.

### Phase 0 — Golden regression harness on Perl v4.0.4 (do this first)

Deliverables (`tests/golden/`, plus a script `tests/golden/capture_goldens.sh`):

1. **A mini boilerplate DB** small enough to commit (a few MB) and fast enough for CI. Build it by
   subsetting a full boilerplate to the SwissProt entries, Pfam families, GO terms, eggNOG ids and
   taxa reachable from the sample-data hits, plus a handful of decoys. Write the subsetting as a
   script so it can be regenerated. Matching search DBs: a `uniprot_sprot.pep` subset (makeblastdb +
   diamond makedb), a Pfam-A.hmm subset (hmmfetch), and an Rfam.cm subset (cmfetch). Then the whole
   `--init` → `--run ALL --use_diamond` → `--report` path runs in CI in a few minutes.
2. **Loader goldens.** For each `--LOAD_*` type, a fixture input file and a dump of the resulting
   tables (`sqlite3 db ".dump TABLE"` or sorted SELECT * output). Include fixtures for signalp6 GFF3,
   tmhmm v2, DeepTMHMM GFF3, EggnogMapper annotations, custom blast, and Infernal. The local sample
   run lacks some of these tools, so craft small fixtures by hand where needed.
3. **Report goldens.** The full report for the sample data under a matrix of options: default; `-E 1e-3`;
   each `--pfam_cutoff`; `--incl_pep --incl_trans`; with a custom-blast column; with EggnogMapper
   columns loaded.
4. **Downstream goldens.** `extract_GO_assignments_from_Trinotate_xls.pl -G -I` (and other flag combos),
   and the `trinotate_report_summary.pl` stats files.
5. **Boilerplate-builder goldens.** Run each parser (`EMBL_swissprot_parser.pl`, `PFAM_dat_parser.pl`,
   `eggNOG5_og_annotations_parser.pl`, `obo_to_tab.pl`, `PFAMtoGoParser.pl`) on small captured slices of the real
   upstream files, and record their bulk-load outputs.
6. A runner (`pytest` is fine even while the implementation is Perl) that executes a given
   implementation (`TRINOTATE_IMPL=perl|python`) against the fixtures and diffs the outputs.

Acceptance: the Perl implementation passes 100% of its own goldens twice in a row. If it doesn't,
nondeterminism exists that must be normalized or fixed first (see §7).

### Phase 1 — Python package skeleton and CLI

- `pyproject.toml` (package `trinotate`, console scripts `Trinotate` and `trinotate`), `src/trinotate/`.
- `cli.py`: argparse that reproduces the legacy flags exactly. Getopt::Long semantics matter here:
  long options with `--`; `-E` short; `--run` takes a quoted space-separated list; Getopt
  `pass_through` and `no_ignore_case` are set. Keep the usage text the same.
- `db.py`: connection helper with `PRAGMA`s; a single read transaction for report reads (the NFS
  lesson); bulk loading via `executemany` inside one transaction. Never use CSV quoting; see §7.
- `pipeline.py`: port of `Pipeliner.pm`. Same checkpoint dir names and **same `.ok` filenames**, so
  a v4 partially-completed run or data dir resumes under v5.
- Delegate not-yet-ported modes to the Perl scripts during the transition, so the CLI is usable at every phase.

### Phase 2 — Loaders (`--init`, `--LOAD_*`)

Port `TrinotateSeqLoader.pl` and each `Trinotate_*_loader.pl` plus the EggnogMapper importer.
Libraries needed: FASTA reading (write a tiny reader; avoid heavy deps) and the ORF/peptide header
parsing used for TransDecoder `.pep` headers. Acceptance: table dumps match the loader goldens.

### Phase 3 — Report writer (`--report`) and GO extraction

Port `util/Trinotate_report_writer.pl` and the query helpers in `PerlLib/Trinotate.pm`:
best-hit selection, E-value filtering, Pfam cutoff semantics, the `^`- and `` ` ``-delimited field
encodings, GO from BLASTX/BLASTP/Pfam, the eggNOG/KEGG lookups, and custom-blast and EggnogMapper columns.
Keep the 4.0.3 fixes:
- the Pfam join uses a range on the **unversioned** accession (`PF00001.` ≤ acc < `PF00001/`), so
  the index stays usable and differing Pfam releases still match (#131);
- reads happen in one transaction.
Port `extract_GO_assignments_from_Trinotate_xls.pl` (needs GO DAG ancestor expansion; see `GO_DAG.pm`).
Acceptance: byte-identical reports across the whole option matrix.

### Phase 4 — Database build (`--create`)

Port `Build_Trinotate_Boilerplate_SQLite_db.pl` and the parsers in `util/admin/util/`. Use
`urllib`/`requests` with retries and resumable downloads instead of shelling out to wget. Keep the
URLs in one module. Current URLs (all verified live in Nov 2026):
- SwissProt: `https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz`
  (EMBL format). `EMBL_swissprot_parser.pl` derives `uniprot_sprot.pep`, the UniprotIndex bulk file **and** the
  TaxonomyIndex from it. There is no separate NCBI taxonomy download.
- Pfam: `https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz`. PFAMreference is parsed from
  the HMM headers (`PFAM_dat_parser.pl`), including the GA/TC/NC cutoffs used by `--pfam_cutoff`.
- eggNOG: `https://eggnog5.embl.de/download/eggnog_5.0/e5.og_annotations.tsv`. Ids are converted to
  UniProt form: COG/KOG/arCOG unchanged, others prefixed `ENOG50`. One description per id, with the
  preferred tax level root > 2759 > 2 > 2157 > 10239; a real description beats a `COG_category:X` placeholder.
- Rfam: `https://ftp.ebi.ac.uk/pub/databases/Rfam/CURRENT/Rfam.cm.gz` and `Rfam.clanin`
- GO: `http://purl.obolibrary.org/obo/go/go-basic.obo` (→ `obo_to_tab.pl`); GO slim from the bundled
  `resources/go/goslim_generic.obo.tab` and `go_slim_mappings.tsv.gz`.
- pfam2go: `http://current.geneontology.org/ontology/external2go/pfam2go` (→ `PFAMtoGoParser.pl`).

Keep the 4.0.4 behavior: copy the boilerplate to the user DB **outside** the checkpointed pipeline,
whenever the target DB is missing (§7). Acceptance: parser goldens match. A full `--create` on a real
machine produces a boilerplate whose table row counts match a Perl-built one (allow for upstream data drift
by building both on the same day).

### Phase 5 — Annotation runs (`--run`)

Port `Trinotate_RUN_annotators` with the same tool command lines, output filenames and checkpoint names.
Acceptance: the sample pipeline end to end (`testing/runMe.sh` pointed at the Python `Trinotate`)
gives a report byte-identical to Perl's on the same machine with the same tool versions.

### Phase 6 — New viewer (replaces TrinotateWeb)

- `trinotate report-html --db x.sqlite -o report.html`: one self-contained HTML file that works
  offline, with everything inlined (no CDN at view time). Contents: summary stats (what
  `trinotate_report_summary.pl`/`make_cXp_html.pl` show today: species, taxonomy, Pfam, eggNOG
  functional categories, GO, KEGG counts) as Plotly charts, plus a searchable/sortable annotation
  table (keyword search over the report).
- `trinotate view --db x.sqlite [--port]`: a local FastAPI app (uvicorn) serving the same views
  plus what TrinotateWeb did with expression data. That means a per-feature report page; keyword search;
  expression heatmaps; DE sample-pair MA/volcano plots; and transcript-cluster views. The data comes
  from the Samples/Replicates/Expression/Diff_expression/ExprCluster* tables, loaded by
  `util/transcript_expression/*` (port those importers too; `testing/runMe.add_expression_prep_TrinotateWeb.sh`
  is the fixture flow). Keep FastAPI/uvicorn/plotly as an **optional extra** (`pip install trinotate[view]`),
  so the core stays dependency-light.
- Then delete `TrinotateWeb/`, `TrinotateWeb.conf`, `run_TrinotateWebserver.pl` and `__launch_TrinotateWeb_*`.
- Acceptance: the user reviews both views on the sample data with expression loaded. Add Playwright or
  similar smoke tests if cheap.

### Phase 7 — Packaging, CI, docs, release

- GitHub Actions: Phase 0 goldens on every PR (mini DB, conda-installed diamond/hmmer/infernal/blast),
  plus a weekly job that HEAD-checks every download URL (link rot broke 4.0.x silently).
  Note: the maintainer's `gh` token lacks the `workflow` scope; pushing `.github/workflows/*` needs SSH
  push (works) or a token refresh.
- pip/PyPI release; bioconda recipe switched to `noarch: python` (see §8 for the recipe history);
  Dockerfile installs the Python package. Bump diamond in the Dockerfile: it pins 2.0.15, conda has
  2.2.x, and the blastx top-hit coords differ between them (159 of 687 rows; 2 different top hits on the sample).
- Docs: README, wiki pages for CLI parity, the viewer, and what was dropped/deferred. Changelog entry.
- Release as v5.0.0 (tag `Trinotate-v5.0.0`, same tag scheme). Keep a `v4` maintenance branch for
  Perl bug fixes.

---

## 5. Perl → Python module map (suggested)

| Perl | Python |
|---|---|
| `Trinotate` (driver) | `trinotate/cli.py`, `trinotate/create.py`, `trinotate/run.py` |
| `PerlLib/Sqlite_connect.pm` | `trinotate/db.py` |
| `PerlLib/Pipeliner.pm` | `trinotate/pipeline.py` |
| `PerlLib/Trinotate.pm` + `util/Trinotate_report_writer.pl` | `trinotate/report.py` |
| `util/trinotateSeqLoader/*` + `util/annotation_importer/*` | `trinotate/loaders/*.py` |
| `util/admin/**` | `trinotate/builddb/*.py` |
| `PerlLib/GO_DAG.pm`, `util/extract_GO_*`, `util/gene_ontology/*` | `trinotate/go.py` |
| `util/report_summary/*` | `trinotate/summary.py` (+ `viewer/`) |
| `util/transcript_expression/*` | `trinotate/expression.py` |
| `TrinotateWeb/**` | `trinotate/viewer/` (report-html + FastAPI app) |
| `Fasta_reader.pm`, `DelimParser.pm`, `Nuc_translator.pm`, `Longest_orf.pm` | small helpers in `trinotate/seqio.py` as needed |
| `Gene_obj.pm`, `GTF*.pm`, `GFF3_utils.pm` | **deferred** (keep Perl scripts) |
| `rnammer_support/`, `functional_enrichment_analysis/`, `*/deprecated/` | ask the user; likely drop |

---

## 6. Development environment (maintainer's host; Broad methods01/methods02)

- **Never submit to UGER** (qsub/qrsh/qlogin). Run everything locally (user directive).
- Work area: `/broad/hptmp/bhaas/TRINOTATE/`. Clone: `Trinotate/`.
- Tools: micromamba at `/broad/hptmp/bhaas/TRINOTATE/tools/bin/micromamba`,
  `MAMBA_ROOT_PREFIX=/broad/hptmp/bhaas/TRINOTATE/tools/mamba`. The env `tools/env` has blast,
  diamond 2.2.9, hmmer, infernal, sqlite, perl-dbi, perl-dbd-sqlite, perl-cgi.
  Use `export PATH=/broad/hptmp/bhaas/TRINOTATE/tools/env/bin:$PATH`.
- **`unset PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT`** before running the Perl code; the user's
  `~/perl5` DBD::SQLite is ABI-incompatible.
- A complete data dir is at `/broad/hptmp/bhaas/TRINOTATE/test_release/TRINOTATE_DATA_DIR`. It includes
  `EGGNOG_DATA_DIR` (22 GB). Reuse it (symlink) instead of re-running `--create`, which takes hours.
  The reference v4.0.3/4.0.4 sample run is at `test_release/` and `test_404/` (reports are byte-identical).
- Apptainer: `/broad/hptmp/bhaas/tools/apptainer-1.5.3/bin/apptainer` (not on PATH). `/tmp` is noexec,
  so set `APPTAINER_CACHEDIR`, `APPTAINER_TMPDIR`, `TMPDIR` **and `PROOT_TMP_DIR`** to a project dir.
- sqlite on NFS (`/broad/hptmp`) is slow per statement (~0.65 ms of locking per query outside a transaction).
- Email the user on long-running status changes: `mail -s SUBJ bhaas@broadinstitute.org`.

---

## 7. Gotchas learned in v4.0.3/4.0.4 (don't regress these)

1. **sqlite `.import` quoting.** `.mode tabs` applies CSV quote parsing. A field starting with `"`
   swallowed ~2.15M rows silently. Python must not use the `csv` module with default quoting for these
   files. Split on `\t` yourself or use `csv.QUOTE_NONE`.
2. **eggNOG ids.** SwissProt cross-references use eggNOG v5 ids (`KOG…`, `COG…`, `ENOG502…`); the old
   4.5 table matched nothing for eukaryotes. Keep the id conversion in §4 Phase 4.
3. **Pfam versions.** Join on the unversioned accession (#131).
4. **Report speed on NFS.** Read in one transaction.
5. **`--create` checkpoint in a shared dir.** Per-project actions (copying the boilerplate to the
   user's DB) must not be checkpointed in the shared `TRINOTATE_DATA_DIR/__chckpts`. Otherwise a
   reused data dir skips them (fixed in 4.0.4).
6. **Report-summary stats tie ordering.** `Trinotate_report_stats.eggnog_counts` and `.pfam.counts` list tied counts
   in Perl hash order, which is random per run. Goldens must compare these files sorted, or (better) Python
   sorts ties deterministically by name and the goldens are regenerated from a Perl run patched the same
   way. Note it in the changelog.
7. **Tool versions change results.** diamond 2.0.15 vs 2.2.9 changes blastx coordinates and E-values.
   Goldens for `--run` must be generated and compared with the same tool versions. Pin them in CI.
8. **Download hosts move.** eggnogdb.embl.de → eggnog5.embl.de; ftp → https for Rfam. Hence the weekly URL check.
9. **Bioconda packaging.** The driver finds helpers relative to itself (`$FindBin::RealBin/util/...`).
   The 4.0.2 recipe flattened scripts into `bin/` and broke every subcommand. The Python package must not
   depend on its install layout this way: use `importlib.resources` for data files, and invoke ported
   code as functions, not as subprocesses.

---

## 8. Release / distribution checklist (how 4.0.3 and 4.0.4 were done)

1. Bump `Changelog.txt` (new section on top), `Docker/VERSION.txt`, and `Docker/Dockerfile`
   (`TRINOTATE_CO=Trinotate-vX.Y.Z`, `TRINOTATE_VERSION=X.Y.Z`). Commit "release X.Y.Z".
2. Run the full sample pipeline (`testing/runMe.sh` against the reused data dir) and compare the report
   with the previous release's.
3. `git tag -a Trinotate-vX.Y.Z` → `git push origin master Trinotate-vX.Y.Z` (SSH remote; the HTTPS
   remote has no credentials) → `gh release create Trinotate-vX.Y.Z --title "Trinotate Release version X.Y.Z"`
   with notes taken from the changelog section.
4. Docker: the user builds and pushes `trinityrnaseq/trinotate:X.Y.Z` and `:latest` on another machine
   (no docker on methods02). Verify the tag via the registry API, then smoke-test with Apptainer.
5. Bioconda: the recipe clone is `/broad/hptmp/bhaas/TRINOTATE/bioconda_recipe/bcr` (shallow;
   remotes `upstream` = bioconda, `fork` = brianjohnhaas, SSH). `git fetch --depth 1 upstream master`,
   branch `trinotate_X.Y.Z` from `upstream/master`, bump version + sha256 (of the GitHub tag tarball),
   push to `fork`, `gh pr create --repo bioconda/bioconda-recipes`. When CI is green, comment
   `@BiocondaBot please add label` (ask the user first). The 4.0.3 recipe installs the tree to
   `$PREFIX/share/trinotate-<ver>` with a `bin/Trinotate` wrapper and sets `TRINOTATE_HOME` on activation.
   It has an end-to-end `--report` test. 4.0.3 was merged as PR #71854; 4.0.4 is PR #71921.
6. Email watcher for PRs: `/broad/hptmp/bhaas/TRINOTATE/watch/watch_bioconda_pr.sh <PR#>`, run detached
   with `setsid nohup`. It only reads and emails; it doesn't post.

---

## 9. Open questions to ask the user (don't decide unilaterally)

1. Drop or keep the legacy extras: `rnammer_support/`, `functional_enrichment_analysis/`,
   `transcript_expression/deprecated/`, `util/shrink_db.pl`, `util/sqlite.pl`, BiNGO export?
2. GTF/GFF3 genome-annotation mode in 5.0: keep it as Perl via the driver, or drop it until 5.1?
3. Minimum Python version (3.9 suggested) and whether PyPI publishing is wanted.
4. Should the tie-ordering fix (§7.6) ship in a Perl 4.0.x release first, so goldens can be exact?
5. Viewer scope: is parity with every TrinotateWeb page required, or is a smaller first version OK
   (report table + summary + expression heatmap + DE plots)?
