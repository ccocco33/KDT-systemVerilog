# #####################################
#  makefile : VCS, SIMV, VERDI
  ####################################

# #####################################
#  makefile : VCS, SIMV, VERDI
# #####################################
.RECIPEPREFIX = >
SRC       = ./rtl/*.sv ./tb/*.sv

EXSRC       = ./exam/*.sv 

EXSRC2 = ./exam/ex02.sv
# #####################################
#  VCS compile option definition
# #####################################
VCS_OPT   = -full64 -sverilog -timescale=1ns/1ps -debug_access+all
VCS_OPT += -kdb -lca
VCS_OPT  += -l comp.log

all: comp sim

comp:
#> vcs $(VCS_OPT) $(EXSRC) -o simv

> vcs $(VCS_OPT) $(EXSRC2) -o simv
sim:
> ./simv -l sim.log

verdi:
> verdi -dbdir simv.daidir -ssf wave.fsdb -nologo &

clean:
> rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h
> rm -rf *.fsdb *.log novas* verdilog

.PHONY: all comp sim verdi clean
