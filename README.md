# HEP Stack

Small Docker-based workspace for a high-energy physics workflow:

- `sim` builds and runs event generation plus Delphes simulation
- `ml` reads the generated ROOT files for inspection or downstream analysis
- `shared-data` is the handoff directory mounted into both containers

## Repository layout

```text
hep_stack/
|-- docker-compose.yaml
|-- README.md
|-- sim/
|   |-- Dockerfile
|   |-- run_sim.sh
|   |-- run_madgraph.sh
|   |-- pythia_to_hepmc3.cc
|   |-- PYTHIA_cards/
|   |   |-- pythia_cmnd_Zmumu.txt
|   |   |-- pythia_cmnd_ZH.txt
|   |   `-- pythia_cmnd_lhef.txt
|   |-- MG_cards/
|   |   |-- madgraph_proc_ZH.txt
|   |   |-- madgraph_proc_ZH_ffbar.txt
|   |   |-- madgraph_proc_Zmumu_ffbar.cfg
|   |   `-- madgraph_proc_Zmumu_ffbar.txt
|   `-- cards/
|-- ml/
|   |-- Dockerfile
|   `-- inspect_root.py
`-- shared-data/
```

## Requirements

- Docker Desktop with Docker Compose enabled

## Build the images

From the repository root:

```powershell
docker compose build
```

The Dockerfiles are platform-aware:

- `linux/amd64`: used by typical Windows/Linux x86 hosts, and also available on Apple Silicon through emulation
- `linux/arm64`: native choice for Apple Silicon

Native Apple Silicon build:

```sh
DOCKER_DEFAULT_PLATFORM=linux/arm64 docker compose build
```

If the native ARM build runs out of memory while compiling ROOT, reduce the ROOT build parallelism:

```sh
DOCKER_DEFAULT_PLATFORM=linux/arm64 docker compose build --build-arg ROOT_BUILD_JOBS=2
```

Apple Silicon with x86 compatibility:

```sh
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker compose build
```

Notes:

- the `sim` image installs a prebuilt ROOT package on `linux/amd64`
- the `sim` image builds ROOT from source on `linux/arm64`. Thus it may take a while (benchmark Apple M1 Pro 4010s)
- the native ROOT source build is intentionally capped to `4` parallel jobs by default; override with `--build-arg ROOT_BUILD_JOBS=<n>` if needed
- the `ml` image uses the same Docker platform selection, but its Python base image is already multi-arch

## Start JupyterLab

```powershell
docker compose up jupyter
```

Then open `http://127.0.0.1:8888` and use the token printed in the terminal.

## Connect to Visual Studio Code 
```powershell
docker compose up -d ml
```
and in VSCode use `Dev Containers: Attach to Running Container...`

## Generate simulation samples

Pure Pythia generation with Delphes:

Background sample:

```powershell
docker compose run --rm sim /workspace/run_sim.sh /workspace/PYTHIA_cards/pythia_cmnd_Zmumu.txt 50000 /data/events_bkg.hepmc /data/delphes_bkg_output.root
```

Signal sample:

```powershell
docker compose run --rm sim /workspace/run_sim.sh /workspace/PYTHIA_cards/pythia_cmnd_ZH.txt 50000 /data/events_sig.hepmc /data/delphes_sig_output.root
```

Generated files appear on the host in `shared-data/`.

MadGraph plus Pythia plus Delphes sample:

```powershell
docker compose run --rm sim /workspace/run_sim.sh madgraph /workspace/MG_cards/madgraph_proc_ZH_ffbar.txt /workspace/PYTHIA_cards/pythia_cmnd_lhef.txt 50000 /data/events_sig_mg.lhe /data/events_sig_mg.hepmc /data/delphes_sig_mg.root
```

MadGraph dimuon background sample:

```powershell
docker compose run --rm sim /workspace/run_sim.sh madgraph /workspace/MG_cards/madgraph_proc_Zmumu_ffbar.txt /workspace/PYTHIA_cards/pythia_cmnd_lhef.txt 50000 /data/events_bkg_mg.lhe /data/events_bkg_mg.hepmc /data/delphes_bkg_mg.root
```

The `madgraph` mode does this inside the container:

```text
MadGraph (MG5_aMC) -> LHE -> Pythia8 shower/hadronization -> HepMC3 -> Delphes
```

Use `sim/MG_cards/madgraph_proc_ZH_ffbar.txt` when you want the MadGraph sample to match the current `sim/PYTHIA_cards/pythia_cmnd_ZH.txt` setup as closely as possible:

- initial state is restricted to quark-antiquark `ZH` production, matching Pythia's `HiggsSM:ffbar2HZ`
- decays are fixed to `Z -> mu+ mu-` and `H -> b b~`

The broader `sim/MG_cards/madgraph_proc_ZH.txt` example is available for a more generic `pp > zh` process card. The Pythia settings for showering external LHE events are in `sim/PYTHIA_cards/pythia_cmnd_lhef.txt`.

For the dimuon background, `sim/MG_cards/madgraph_proc_Zmumu_ffbar.txt` mirrors `sim/PYTHIA_cards/pythia_cmnd_Zmumu.txt` by using quark-antiquark Drell-Yan production, and the matching MadGraph run-card settings live in `sim/MG_cards/madgraph_proc_Zmumu_ffbar.cfg`.

MadGraph settings still live outside the bash in `sim/MG_cards/*.cfg`, but the execution is in one place: `run_madgraph.sh` creates the process directory, updates `run_card.dat`, runs event generation, and exports the produced LHE file.

Example for dark photon HAHM model:

```powershell
docker compose run --rm sim /workspace/run_sim.sh madgraph /workspace/MG_cards/madgraph_proc_signal_hZpZp.txt /workspace/PYTHIA_cards/pythia_cmnd_signal_ctau50.txt 50000 /data/events_sig_ctau50_mg.lhe /data/events_sig_ctau50_mg.hepmc /data/delphes_sig_ctau50_mg.root /workspace/cards/delphes_card_ATLAS_tracks.tcl /workspace/MG_cards/madgraph_proc_signal_hZpZp.cfg /workspace/MG_cards/param_card_signal_Zp04.dat
```
with background:
```powershell

docker compose run --rm sim \
  /workspace/run_sim.sh \
  madgraph \
  /workspace/MG_cards/madgraph_proc_ZZ_4mu.txt \
  /workspace/PYTHIA_cards/pythia_cmnd_ZZ_4mu.txt \
  50000 \
  /data/events_bkg_ZZ4mu_mg.lhe \
  /data/events_bkg_ZZ4mu_mg.hepmc \
  /data/delphes_bkg_ZZ4mu_mg.root \
  /workspace/cards/delphes_card_ATLAS_tracks.tcl \
  /workspace/MG_cards/madgraph_proc_signal_hZpZp.cfg
```


## Inspect output from the ML container

```powershell
docker compose run --rm ml python /workspace/inspect_root.py
```

This reads the ROOT file from `/data` and writes a parquet file back into `shared-data/`.

## Open an interactive shell

Simulation container:

```powershell
docker compose run --rm sim
```

ML container:

```powershell
docker compose run --rm ml
```

## Shared data mount

Both containers mount the same host folder:

```text
./shared-data -> /data
```

That means the simulation container can write files once and the ML container can read them immediately.
