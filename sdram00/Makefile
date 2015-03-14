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
TSIMVHDFILE = $(WORKDIR)/time_sim.vhd
TSIMSDFFILE = $(WORKDIR)/time_sim.sdf

RTLSOURCES = top.vhd sdramc.vhd ram16xyd.vhd confinit.vhd
FSIMSOURCES = sim.vhd
TSIMSOURCES = sim.vhd $(TSIMVHDFILE)

all: $(MCSFILE)
synth: $(NGCFILE)
fit: $(NCDFILE)
bit: $(BITFILE)
mcs: $(MCSFILE)

clean:
	rm -rf $(WORKDIR) xflow.his _impact* fuse* isim isim.* *.exe

$(NGCFILE): $(PRJFILE) $(RTLSOURCES)
	$(XFLOW) -synth xst_mixed.opt $<

$(NCDFILE): $(NGCFILE) $(UCFFILE)
	cp $(UCFFILE) $(WORKDIR)
	$(XFLOW) -implement balanced.opt $<

$(BITFILE): $(NCDFILE)
	$(XFLOW) -config bitgen.opt $<

$(TSIMVHDFILE) $(TSIMSDFFILE): $(NCDFILE)
	$(XFLOW) -tsim generic_vhdl.opt $<

$(BINFILE): $(BITFILE)
	$(PROMGEN) -u 0 $(BITFILE) -o $(MCSFILE)

$(MCSFILE): $(BINFILE) $(DATFILE)
	cat $(BINFILE) > $(TMPFILE)
	env printf '\xde\xad\xbe\xef' >> $(TMPFILE)
	cat $(DATFILE) >> $(TMPFILE)
	objcopy -I binary -O ihex $(TMPFILE) $@

cfg: $(CMDFILE) $(MCSFILE)
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
	fuse -o $@ work.sim

fsim: fsim.exe fsim.tcl
	./$< -gui -tclbatch fsim.tcl

tsim: tsim.exe tsim.tcl $(TSIMSDFFILE)
	./$< -gui -tclbatch tsim.tcl -sdftyp $(TSIMSDFFILE) -sdfroot /u0

.PHONY: all synth fit bit mcs clean cfg fsim tsim
