NSLS2-EM FPGA Platform

This is the FPGA gateware and ARM software for a custom designed hardware platform for the NSLS2 Electrometer electroncs.

Uses the DESY FWK FPGA Firmware Framework https://fpgafw.pages.desy.de/docs-pub/fwk/index.html

Clone with --recurse-submodules to get the FWK repos

git clone --recurse-submodules https://github.com/NSLS-II/nsls2em-fpga

Setup Environment: make env (first time only)

To build firmware make cfg=hw project (Sets up project)

make cfg=hw gui (Open in Vivado)

make cfg=hw build (Builds bit file)

To build Software

make cfg=sw project (Sets up project)

make cfg=sw gui (Opens in Vitis)

make cfg=sw build (Builds executable)

