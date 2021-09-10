#include <stdlib.h>
#include <verilated_fst_c.h>
#include <verilated_cov.h>

#include "Vtwo_chip.h"
#include "Vtwo_chip__Dpi.h"
#include "bsg_nonsynth_dpi_clock_gen.hpp"
using namespace bsg_nonsynth_dpi;

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(VM_TRACE_FST);
  Verilated::assertOn(false);
//Verilated::debug(1);

  Vtwo_chip *tb = new Vtwo_chip("two_chip");

  svScope g_scope = svGetScopeFromName("two_chip");
  svSetScope(g_scope);

  // Let clock generators register themselves.
  tb->eval();

  // Use me to find the correct scope of your DPI functions
  //Verilated::scopesDump();

#if VM_TRACE_FST
  std::cout << "Opening dump file" << std::endl;
  VerilatedFstC* wf = new VerilatedFstC;
  tb->trace(wf, 10);
  wf->open("dump.fst");
#endif

  while(tb->reset_o == 1) {
    bsg_timekeeper::next();
    tb->eval();
    #if VM_TRACE_FST
      wf->dump(sc_time_stamp());
    #endif
  }

  Verilated::assertOn(true);

  unsigned long cnt = 0;
  while (!Verilated::gotFinish()) {
    bsg_timekeeper::next();
    tb->eval();
    #if VM_TRACE_FST
      wf->dump(sc_time_stamp());
    #endif
    if((cnt % 4096UL) == 0)
      std::cout << "Iteration: " << cnt << std::endl;
    cnt++;
  }
  std::cout << "Finishing test" << std::endl;

#if VM_COVERAGE
  std::cout << "Writing coverage" << std::endl;
  VerilatedCov::write("coverage.dat");
#endif


  #if VM_TRACE_FST
    std::cout << "Closing dump file" << std::endl;
    wf->close();
  #endif

  std::cout << "Executing final" << std::endl;
  tb->final();

  std::cout << "Exiting" << std::endl;
  exit(EXIT_SUCCESS);
}

