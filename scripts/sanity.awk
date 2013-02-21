#!/usr/bin/awk -f

#
# Sanity checks for C functions and declarations.
#
# This program does not distinct between errors and bad style.
#
# @retval 0
#	No problems encountered
# @retval 1
#	Duplicated prototype
# @retval 2
#	Duplicated prototypes mismatching
# @retval 3
#	Prototype following function definition
# @retval 4
#	Function definition and prototype mismatch
# @retval 5
#	Function defined multiple times
#

BEGIN {
	# Get a unique temporary file
	cmd = "sh -c 'printf $$'"
	cmd | getline TMPFILE
	close(cmd)
	TMPFILE = "/tmp/sanity.awk." TMPFILE
	# Get cstrip cmd
	path = ENVIRON["LIBPROJDIR"]
	sub(/.+/, "&/", path)
	cmd = ARGV[0] " -f " path "scripts/cstrip.awk"
	for (i = 1; i < ARGC; i++) {
		cmd = cmd " '" ARGV[i] "' "
	}
	system(cmd "-DSDCC >" TMPFILE)
	delete ARGV
	ARGV[1] = TMPFILE
	ARGC = 2
}

/^#[0-9]+".*"/ {
	sub(/^[^"]*"/, "")
	sub(/"[^"]*/, "")
	filename = $0
	next
}

# Get prototypes
!/^(return|else|__sfr|__sfr16|__sbit) / && /[[:alnum:]_* ]+ [[:alnum:]_]+\(.*\)[[:alnum:]_* ]*;/ {
	declare = $0
	sub(/\(.*/, "", declare)
	sub(/.* /, "", declare)
	sub(/;/, "")
	if (prototypes[declare]) {
		print filename ": redeclares prototype:"
		print "	" $0
		if (prototypes[declare] != $0) {
			print protofiles[declare] ": previous mismatching declaration:"
			print "	" prototypes[declare]
			exit 2
		}
		print protofiles[declare] ": previous declaration"
		exit 1
	}
	prototypes[declare] = $0
	protofiles[declare] = filename
	if (functions[declare]) {
		print filename ": prototype for already defined function:"
		print "	" $0
		if (functions[declare] != $0) {
			print funcfiles[declare] ": previous mismatching definition:"
			print "	" functions[declare]
			exit 3
		}
		print funcfiles[declare] ": previous definition"
		exit 3
	}
	next
}

# Get definitions
!/^(else) / && /[[:alnum:]_* ]+ [[:alnum:]_]+\(.*\)[[:alnum:]_* ]*$/ {
	definition = $0
	sub(/\(.*/, "", definition)
	sub(/.* /, "", definition)
	if (prototypes[definition]) {
		if (prototypes[definition] != $0) {
			print filename ": function definition not matching prototype:"
			print "	" $0
			print protofiles[definition] ": prototype:"
			print "	" prototypes[definition]
			exit 4
		}
	}
	if (functions[definition]) {
		print filename ": duplicated function:"
		print "	" $0
		if (functions[definition] != $0) {
			print funcfiles[definition] ": previous mismatching definition:"
			print "	" functions[definition]
			exit 5
		}
		print funcfiles[definition] ": previous definition"
		exit 5
	}
	functions[definition] = $0
	funcfiles[definition] = filename
	next
}

END {
	# Stop writing to TMPFILE
	close(TMPFILE)
	cmd = "rm " TMPFILE
	system(cmd)
}
