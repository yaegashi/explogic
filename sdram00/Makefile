WORKDIR = work
REPORTDIR = report
EXPORTDIR = export

TOP = top
FPGAPART = xc3s500e-fg320-4
PROMPART = xcf04s
XFLOW = xflow -p $(FPGAPART) -wd $(WORKDIR) -rd $(REPORTDIR) -ed $(EXPORTDIR)
PROMGEN = promgen -x $(PROMPART) -w -p bin
PRJFILE = $(TOP).prj
UCFFILE = $(TOP).ucf
DATFILE = $(TOP).dat
CMDFILE = $(TOP).cmd
TMPFILE = $(WORKDIR)/tmp.bin
NGCFILE = $(WORKDIR)/$(TOP).ngc
NCDFILE = $(WORKDIR)/$(TOP).ncd
BITFILE = $(WORKDIR)/$(TOP).bit
BINFILE = $(WORKDIR)/$(TOP).bin
MCSFILE = $(WORKDIR)/$(TOP).mcs
SVFFILE = $(WORKDIR)/$(TOP).svf
FSIMFILE = $(WORKDIR)/func_sim.vhd
TSIMFILE = $(WORKDIR)/time_sim.vhd

RTLSOURCES = top.vhd sdramc.vhd
FSIMSOURCES = sim.vhd
TSIMSOURCES = sim.vhd $(TSIMFILE)

all: $(MCSFILE)
synth: $(NGCFILE)
fit: $(NCDFILE)
bit: $(BITFILE)
svf: $(SVFFILE)

clean:
	rm -rf $(WORKDIR) xflow.his _impact* fuse* isim isim.* *.exe

$(NGCFILE): $(PRJFILE) $(RTLSOURCES)
	$(XFLOW) -synth xst_mixed.opt $<

$(NCDFILE): $(NGCFILE) $(UCFFILE)
	cp $(UCFFILE) $(WORKDIR)
	$(XFLOW) -implement balanced.opt $<

$(BITFILE): $(NCDFILE)
	$(XFLOW) -config bitgen.opt $<

$(TSIMFILE): $(NCDFILE)
	$(XFLOW) -tsim generic_vhdl.opt $<

$(BINFILE): $(BITFILE)
	$(PROMGEN) -u 0 $(BITFILE) -o $(MCSFILE)

$(MCSFILE): $(BINFILE) $(DATFILE)
	cat $(BINFILE) > $(TMPFILE)
	printf '\xde\xad\xbe\xef' >> $(TMPFILE)
	cat $(DATFILE) >> $(TMPFILE)
	objcopy -I binary -O ihex $(TMPFILE) $@

cfg: $(CMDFILE) $(BITFILE)
	impact -batch $(CMDFILE)

fsim.exe: $(RTLSOURCES) $(FSIMSOURCES)
	vhpcomp -prj $(PRJFILE)
	vhpcomp $(FSIMSOURCES)
	vlogcomp -d x16 -d sg6T micron/ddr.v
	fuse -notimingchecks -o $@ work.sim

tsim.exe: $(RTLSOURCES) $(TSIMSOURCES)
	vhpcomp -prj $(PRJFILE)
	vhpcomp $(TSIMSOURCES)
	vlogcomp -d x16 -d sg6T micron/ddr.v
	fuse -notimingchecks -o $@ work.sim

fsim: fsim.exe fsim.tcl
	./$< -gui -tclbatch fsim.tcl

tsim: tsim.exe tsim.tcl
	./$< -gui -tclbatch tsim.tcl
