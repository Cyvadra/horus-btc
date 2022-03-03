# horus

### Todos:
1. [ ] Rewrite MmapDB, support bson storage, remove Mmap dependency.
3. [ ] Design TxRows storage format.
5. [ ] FinanceDB: online data loading.

## Pending:
11. [ ] Online AddressService.
7. [ ] Feature: Different alignment of timestamp, so as to generate more data (after version update)
9. [ ] Add MA to dnn input. FinanceDB rewrite might be required.

### Issues:
- [ ] Original version might have missing value(records).

### Cancelled:
5. [x] Batch calculation failed due to same performance and lower accuracy.
3. [x] Timestamp-snapshot supported Mmap database ==> Update Address Service.

### Tests:
- [x] AddressService(part 1) test.
- [x] AddressService(part 2) test compared to previous snapshot at 2018.01.01.
