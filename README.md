# horus

### Todos:
3. [x] AddressService totally moved into memory.
5. [ ] FinanceDB: online data loading.
7. [ ] Feature: Different alignment of timestamp, so as to generate more data (after version update)
9. [ ] Add MA to dnn input. FinanceDB rewrite might be required.

### Tests:
- [x] AddressService(part 1) test.
- [x] AddressService(part 2) test compared to previous snapshot at 2018.01.01.

### Processing:
11. [ ] Consider real-time update.

### Issues:
- [ ] Original version might have missing value(records).
- [x] New version of AddressService failed due to performance issue, deprecated by now.

### Cancelled:
5. [ ] Big Update: support batch calculation and touch!() function (or next generation of AddressService)
3. [x] Timestamp-snapshot supported Mmap database ==> Update Address Service.

