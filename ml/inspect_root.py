import uproot
import awkward as ak
import pandas as pd

path = "/data/delphes_sig_output.root"
tree = uproot.open(path)["Delphes"]

branches = ["Muon.PT", "Muon.Eta", "Muon.Phi", "Jet.PT", "Jet.Eta", "Jet.Phi", "MissingET.MET"]
arrays = tree.arrays(branches, library="ak")
max_objects = 4
object_branches = ["Muon.PT", "Muon.Eta", "Muon.Phi", "Jet.PT", "Jet.Eta", "Jet.Phi"]

features = {}

for name in object_branches:
    padded = ak.fill_none(
        ak.pad_none(arrays[name], max_objects, axis=1, clip=True),
        0,
    )

    prefix = name.lower().replace(".", "_")
    for idx in range(max_objects):
        features[f"{prefix}_{idx + 1}"] = padded[:, idx]

# MissingET is an event-level feature; Delphes usually stores it as
# a one-object collection, so take the first entry per event.
features["met"] = ak.fill_none(ak.firsts(arrays["MissingET.MET"]), 0)

table = {
    name: ak.to_numpy(values)
    for name, values in features.items()
}
df = pd.DataFrame(table)
print("Branches loaded:")
for b in branches:
    print("  ", b)

print("\nNumber of events:", len(arrays["Muon.PT"]))

mu_counts = ak.num(arrays["Muon.PT"])
jet_counts = ak.num(arrays["Jet.PT"])

print("Average muons/event:", ak.mean(mu_counts))
print("Average jets/event :", ak.mean(jet_counts))

print("\nAutoencoder input features:")
for name in df.columns:
    print("  ", name)

df.to_parquet("/data/delphes_ZH.parquet", index=False)
print("\nWrote /data/delphes_ZH.parquet")
