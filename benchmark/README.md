# Benchmark Methodology
Upon benchmarking, you want to:
- **Use a warm I-Cache and a warm branch predictor.**
  We run one discarded warm-up of each kernel before the timed run. This removes compulsory instruction misses and predictor training from the measurement, and trains both paths identically. Neither effect belongs to the data-movement problem being measured.

- **Use a cold D-Cache.**
  Before every timed run, we write back and invalidate the source and destination lines with Zicbom `cbo.flush`. This is a more realistic regime (tensors are usually larger than L1 and were written earlier), and it is required for correctness: HYDRA reads main RAM directly, so dirty lines left in the write-back D$ would make it transpose stale data. We are using `cbo.flush` rather than `fence.i`, which also invalidates the I$ and would undo the warm-up (see `src/ieu/controller.sv`). We also run a separate warm-D$ sweep as a labeled secondary result.

- **Measure the full offload cost.**
  The timed window covers MMR programming, launch, the transfer itself, and the completion poll, not just the accelerated task. Counter-read overhead is measured separately and reported.

- **Insert compiler barriers.**
  Every counter read carries a `"memory"` clobber so the compiler cannot move loads or stores across the timestamps. No hardware fence is used, because an ordinary `FENCE` is a nop on Wally (in-order core, blocking memory accesses).

- **Prevent inlining and cloning of timed kernels.**
  We mark the timed kernels `__attribute__((noipa))`. At `-O3` the compiler can otherwise inline them or constant-propagate the transfer length into a specialized copy, so different sweep points would run different machine code.

- **Verify outside the timed window.**
  We check each output right after its own run, against a seeded pattern pre-filled with a poison value so stale data cannot pass. We print results only after both measurements are captured.

- **Take one measurement per boot for published data.**
  Compile each length as a separate build and run it from reset, so every data point starts from identical architectural state. The in-binary sweep is for debugging only.


# Setup
In order to compile and run C code into Wally, you need to have installed the [**RISC-V GNU Toolchain**](https://github.com/riscv-collab/riscv-gnu-toolchain). Once installed:
1. Edit `wally/setup.sh` (specifically lines 26-29) to include the path to your toolchain installation. For example, at Rice, that is under `/clear/apps/riscv`. Note that you might also want to move line 39 (`export PATH=$WALLY/bin:$PATH`) to the bottom of the script to avoid conflicts with RISC-V site paths.
2. Save this edit as a patch, so you don't have to worry about it being overwritten after future updates:
```bash
$ cd ../scripts
$ wally save
$
$ # Verify that updating Wally doesn't cause any change
$ wally update 
```
Note that this particular patch is .gitignore'd so no sensitive data will leak out.

3. Update your PATH `wally/setup.sh`: 
```bash
$ source wally/setup.sh
```
4. Make the previous step automatic upon login by adding these lines to your `.bashrc`: 
```bash
export WALLY=$PATH_TO_HYDRA/wally

# Source Wally setup script
if [ -f "$WALLY/setup.sh" ]; then
    source "$WALLY/setup.sh" 1>/dev/null
fi
```
Note that `1>/dev/null` hides stdout, but will still allow to show any errors. 

5. [OPTIONAL] Depending on whether you're working on a remote cluster and your available quota, you might also want to add the following line to your `.bashrc` to avoid exceeding provided space:
```bash
export UV_CACHE_DIR=/tmp/$USER/uv_cache
```
This ensures that Wally's setup script doesn't create a heavy Python virtual environment in your own personal space.

6. Now you should be ready to compile and run C code into Wally. Simply modify the Makefile `TARGET` line to make sure it points at the file you want to run, for example `hydra_test.c`, then:
```bash
$ # Compile your C code
$ make
$
$ # Run your compiled C code
$ wsim rv32gc --sim questa --elf hydra_test
```
