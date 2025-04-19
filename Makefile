BINFOLDER := bin/
INCFOLDER := inc/
SRCFOLDER := src/
OBJFOLDER := obj/
TESTFOLDER := test/
COVFOLDER := cov/

CC := gcc
CFLAGS := -Wall -lpthread -lm -lrt -I$(INCFOLDER)
TESTFLAGS := -DUNITY_OUTPUT_COLOR -DTEST_MODE -DUNITY_INCLUDE_DOUBLE
COVFLAGS := -fprofile-arcs -ftest-coverage -fcondition-coverage

SRCFILES := $(wildcard $(SRCFOLDER)*.c)

all: $(SRCFILES:src/%.c=obj/%.o)
	$(CC) $(CFLAGS) obj/sensors.o obj/mq_utils.o obj/file_reader.o obj/log_utils.o obj/dbc.o -o bin/sensors_bin
	$(CC) $(CFLAGS) obj/actuators.o obj/mq_utils.o obj/file_reader.o obj/log_utils.o obj/dbc.o -o bin/actuators_bin
	$(CC) $(CFLAGS) obj/aeb_controller.o obj/mq_utils.o obj/file_reader.o obj/log_utils.o obj/dbc.o obj/ttc_control.o -o bin/aeb_controller_bin -lm -lrt
	$(CC) $(CFLAGS) obj/main.o obj/mq_utils.o obj/file_reader.o obj/log_utils.o obj/dbc.o -o bin/main_bin

obj/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

run:
	./bin/main_bin

TESTFILES := $(wildcard $(TESTFOLDER)test_*.c)
TESTS := $(patsubst $(TESTFOLDER)%.c, $(TESTFOLDER)%, $(TESTFILES))

# Mapping between test files and their corresponding source files
TEST_SRC_MAP := \
	test_mq_utils.c:mq_utils.c \
	test_file_reader.c:file_reader.c \
	test_log_utils.c:log_utils.c \
	test_ttc_control.c:ttc_control.c \
	test_actuators.c:actuators.c \
	test_aeb_controller.c:aeb_controller.c \
	test_sensors.c:sensors.c

.PHONY: test test_all
test:
	@if [ -z "$(file)" ]; then \
		$(MAKE) --no-print-directory test_all; \
	else \
		test_exe="$(TESTFOLDER)$(basename $(file))"; \
		echo "Compiling and running test $$test_exe"; \
		$(MAKE) --no-print-directory $$test_exe; \
		./$$test_exe; \
	fi

test_all: $(TESTS)
	@for test in $^; do \
		echo "\n\033[1;33mTest $$test results:\033[0m"; \
		./$$test; \
	done

test/test_mq_utils: test/test_mq_utils.c src/mq_utils.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) test/test_mq_utils.c src/mq_utils.c test/unity.c -o test/test_mq_utils -I$(TESTFOLDER)

test/test_file_reader: test/test_file_reader.c src/file_reader.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) test/test_file_reader.c src/file_reader.c test/unity.c -o test/test_file_reader -I$(TESTFOLDER)

test/test_log_utils: test/test_log_utils.c src/log_utils.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) -Wl,--wrap=fopen -Wl,--wrap=perror test/test_log_utils.c src/log_utils.c test/unity.c -o test/test_log_utils -I$(TESTFOLDER)

test/test_ttc_control: test/test_ttc_control.c src/file_reader.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) test/test_ttc_control.c src/ttc_control.c test/unity.c -o test/test_ttc_control -I$(TESTFOLDER) -lm -lrt

test/test_actuators: test/test_actuators.c src/actuators.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) test/test_actuators.c src/actuators.c test/unity.c -o test/test_actuators -Iinc -Itest -lpthread	

test/test_aeb_controller: test/test_aeb_controller.c src/aeb_controller.c src/ttc_control.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) test/test_aeb_controller.c src/aeb_controller.c src/ttc_control.c test/unity.c -o test/test_aeb_controller -I$(TESTFOLDER) -lm

test/test_sensors: test/test_sensors.c src/sensors.c test/unity.c
	$(CC) $(CFLAGS) $(TESTFLAGS) test/test_sensors.c src/sensors.c test/unity.c -o test/test_sensors -I$(TESTFOLDER) -Itest -lpthread

# Coverage targets
.PHONY: cov lcov full-cov clean-cov

cov:
	if [ -z "$(src_file)" ] || [ -z "$(test_file)" ]; then \
		echo "Please provide both src_file and test_file as arguments, e.g., 'make cov src_file=example.c test_file=test_example.c'"; \
	else \
		echo "Running gcov for source file $(src_file) and test $(test_file)"; \
		echo ""; \
		if [ "$(test_file)" = "test_log_utils.c" ]; then \
			WRAP_FLAGS="-Wl,--wrap=fopen -Wl,--wrap=perror"; \
		else \
			WRAP_FLAGS=""; \
		fi; \
		$(CC) $(TESTFLAGS) $(COVFLAGS) $$WRAP_FLAGS $(SRCFOLDER)$(src_file) -lm -lrt $(TESTFOLDER)$(test_file) $(TESTFOLDER)unity.c -I$(INCFOLDER) -o $(OBJFOLDER)$(test_file:.c=)_gcov_bin; \
		./$(OBJFOLDER)$(test_file:.c=)_gcov_bin > /dev/null 2>&1; \
		gcov -b $(SRCFOLDER)$(src_file) -o $(OBJFOLDER)$(test_file:.c=)_gcov_bin-$(src_file:.c=.gcda); \
	fi

lcov:
	@if [ -z "$(src_file)" ] || [ -z "$(test_file)" ]; then \
		echo "Please provide both src_file and test_file as arguments, e.g., 'make lcov src_file=example.c test_file=test_example.c'"; \
	else \
		mkdir -p $(COVFOLDER); \
		echo "Running lcov for source file $(src_file) and test $(test_file)"; \
		echo ""; \
		if [ "$(test_file)" = "test_log_utils.c" ]; then \
			WRAP_FLAGS="-Wl,--wrap=fopen -Wl,--wrap=perror"; \
		else \
			WRAP_FLAGS=""; \
		fi; \
		$(CC) $(TESTFLAGS) $(COVFLAGS) $$WRAP_FLAGS $(SRCFOLDER)$(src_file) -lm -lrt $(TESTFOLDER)$(test_file) $(TESTFOLDER)unity.c -I$(INCFOLDER) -o $(OBJFOLDER)$(test_file:.c=)_lcov_bin; \
		./$(OBJFOLDER)$(test_file:.c=)_lcov_bin > /dev/null 2>&1; \
		lcov --mcdc-coverage --rc lcov_branch_coverage=1 --capture --directory . --output-file $(COVFOLDER)$(src_file:.c=.info) --no-external; \
		genhtml --mcdc-coverage --branch-coverage $(COVFOLDER)$(src_file:.c=.info) --output-directory $(COVFOLDER)$(src_file:.c=)_report; \
		echo "LCOV report generated at $(COVFOLDER)$(src_file:.c=)_report/index.html"; \
	fi

full-cov: clean-cov
	@echo "Running full coverage analysis for all tests..."
	@mkdir -p $(COVFOLDER)
	@$(foreach pair, $(TEST_SRC_MAP), \
		$(eval test_file := $(word 1,$(subst :, ,$(pair)))) \
		$(eval src_file := $(word 2,$(subst :, ,$(pair)))) \
		echo "\nProcessing $(test_file) for $(src_file)"; \
		if [ "$(test_file)" = "test_log_utils.c" ]; then \
			WRAP_FLAGS="-Wl,--wrap=fopen -Wl,--wrap=perror"; \
		else \
			WRAP_FLAGS=""; \
		fi; \
		$(CC) $(TESTFLAGS) $(COVFLAGS) $$WRAP_FLAGS $(SRCFOLDER)$(src_file) -lm -lrt $(TESTFOLDER)$(test_file) $(TESTFOLDER)unity.c -I$(INCFOLDER) -o $(OBJFOLDER)$(test_file:.c=)_cov_bin; \
		./$(OBJFOLDER)$(test_file:.c=)_cov_bin > /dev/null 2>&1; \
		gcov -b $(SRCFOLDER)$(src_file) -o $(OBJFOLDER)$(test_file:.c=)_cov_bin-$(src_file:.c=.gcda); \
	)
	@echo "\nGenerating combined LCOV report..."
	@lcov --mcdc-coverage --rc lcov_branch_coverage=1 --capture --directory . --output-file $(COVFOLDER)combined.info --no-external
	@genhtml --mcdc-coverage --branch-coverage $(COVFOLDER)combined.info --output-directory $(COVFOLDER)full_report
	@echo "\nFull coverage analysis complete!"
	@echo "Individual GCOV reports generated in the source directory"
	@echo "Combined LCOV report available at $(COVFOLDER)full_report/index.html"

cppcheck:
	cppcheck --addon=misra -I ./inc --force --library=posix $(SRCFOLDER) $(INCFOLDER)

.PHONY: docs
docs:
	doxygen Doxyfile

.PHONY: clean-docs
clean-docs:
		find docs/ -mindepth 1 ! -name '*.pdf' ! -name '.gitkeep' ! -name '*.dox' -print0 | xargs -0 rm -rf


.PHONY: clean clean-cov
clean:
	rm -rf obj/*
	rm -rf bin/*
	rm -f $(TESTS)
	rm -f *.gcov
	rm -f *.gcda
	rm -f *.gcno

clean-cov:
	rm -rf $(COVFOLDER)*
	rm -f *.info