# horus

### Todos:
1. [ ] Implementation of the whole pipeline.
3. [ ] Check AddressService's validity.
5. [ ] Apply current model.

### Done:
1. [x] Benchmark: GetBlockCoins, Address2StateDiff

### Pending:
3. [ ] Train latest model.
7. [ ] Feature: Different alignment of timestamp, so as to generate more data (after version update)
9. [ ] Add MA to dnn input. FinanceDB rewrite might be required.
1. [x] Rewrite MmapDB, remove Mmap dependency.
11. [x] Online AddressService.
5. [x] FinanceDB: online data loading.

### Issues:
- [x] Original version might have missing value(records).

### Cancelled:
5. [ ] Modify address2id.ng.jl, save string list to files, IOStream instead of IOBuffer, to reduce huge mem occupation.
5. [x] Batch calculation failed due to same performance and lower accuracy.
3. [x] Timestamp-snapshot supported Mmap database ==> Update Address Service.

### Tests:
- [x] AddressService(part 1) test.
- [x] AddressService(part 2) test compared to previous snapshot at 2018.01.01.
