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
|   |-- pythia_to_hepmc3.cc
|   |-- pythia_cmnd_Zmumu.txt
|   |-- pythia_cmnd_ZH.txt
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

If you are on Apple silicon and the simulation image needs x86 compatibility:

```powershell
docker compose build --platform linux/amd64
```

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

Background sample:

```powershell
docker compose run --rm sim /workspace/run_sim.sh /workspace/pythia_cmnd_Zmumu.txt 50000 /data/events_bkg.hepmc /data/delphes_bkg_output.root
```

Signal sample:

```powershell
docker compose run --rm sim /workspace/run_sim.sh /workspace/pythia_cmnd_ZH.txt 50000 /data/events_sig.hepmc /data/delphes_sig_output.root
```

Generated files appear on the host in `shared-data/`.

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