import uproot
import awkward as ak

path = "/data/delphes_bkg_output.root"
tree = uproot.open(path)["Delphes"]

branches = ["Muon.PT", "Muon.Eta", "Jet.PT", "Jet.Eta", "MissingET.MET"]
arrays = tree.arrays(branches, library="ak")

print("Branches loaded:")
for b in branches:
    print("  ", b)

print("\nNumber of events:", len(arrays["Muon.PT"]))

mu_counts = ak.num(arrays["Muon.PT"])
jet_counts = ak.num(arrays["Jet.PT"])

print("Average muons/event:", ak.mean(mu_counts))
print("Average jets/event :", ak.mean(jet_counts))

ak.to_parquet(arrays, "/data/delphes.parquet")
print("\nWrote /data/delphes.parquet")