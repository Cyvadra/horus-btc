# horus

### Todos:
3. [ ] Client-side visualization.

### Pending:
11. [x] Separate AddressService?

### Done:
1. [x] Rewrite MmapDB, remove Mmap dependency.
1. [x] Benchmark: GetBlockCoins, Address2StateDiff.
5. [x] FinanceDB: online data loading.
5. [x] Feature: Rewrite interval logic, sync results with block instead of fixed interval, so as to improve flexibility and timeliness.
5. [x] Auto-save address2id service.
7. [x] Feature: Different alignment of timestamp, so as to generate more data (after version update)
1. [x] Update calculation service.

### Issues:

### Cancelled:
3. [ ] Train latest model.
5. [ ] Modify address2id.ng.jl, save string list to files, IOStream instead of IOBuffer, to reduce huge mem occupation.
7. [x] Original version might have missing value(records).
9. [x] Add MA to dnn input. FinanceDB rewrite might be required.
5. [x] Batch calculation failed due to same performance and lower accuracy.
3. [x] Timestamp-snapshot supported Mmap database ==> Update Address Service.

### Tests:
- [x] AddressService(part 1) test.
- [x] AddressService(part 2) test compared to previous snapshot at 2018.01.01.
