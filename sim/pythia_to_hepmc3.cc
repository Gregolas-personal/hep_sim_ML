#include "Pythia8/Pythia.h"
#include "HepMC3/GenEvent.h"
#include "HepMC3/WriterAscii.h"
#include "Pythia8Plugins/HepMC3.h"

#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    std::string cmndFile = "pythia_cmnd_Zmumu.txt";
    std::string outFile = "events.hepmc";
    int nEvents = 10000;

    if (argc > 1) cmndFile = argv[1];
    if (argc > 2) outFile = argv[2];
    if (argc > 3) nEvents = std::stoi(argv[3]);

    Pythia8::Pythia pythia;
    pythia.readFile(cmndFile);
    pythia.readString("Main:numberOfEvents = " + std::to_string(nEvents));

    if (!pythia.init()) {
        std::cerr << "PYTHIA init failed\n";
        return 1;
    }

    HepMC3::Pythia8ToHepMC3 toHepMC;
    HepMC3::WriterAscii writer(outFile);

    for (int iEvent = 0; iEvent < nEvents; ++iEvent) {
        if (!pythia.next()) continue;

        HepMC3::GenEvent hepmcEvent;
        toHepMC.fill_next_event(pythia, hepmcEvent);
        writer.write_event(hepmcEvent);
    }

    writer.close();
    pythia.stat();
    return 0;
}
