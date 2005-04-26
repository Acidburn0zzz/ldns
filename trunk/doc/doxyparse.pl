#!/usr/bin/perl

# Doxygen is usefull for html documentation, but sucks 
# in making manual pages. Still tool also parses the .h
# files with the doxygen documentation and creates
# the man page we want
#
# 2 way process
# 1. All the .h files are processed to create in file in which:
# filename | API | description | return values
# are documented
# 2. Another file is parsed which states which function should
# be grouped together in which manpage. Symlinks are also created.
#
# With this all in place, all documentation should be autogenerated
# from the doxydoc.

use Getopt::Std;

my $state;
my $description;
my $key;
my $return;
my $param;
my $api;
my $const;

my %description;
my %api;
my %return;
my %options;
my %manpages;

my $MAN_SECTION = "3";
my $MAN_HEADER = ".TH ldns  \"25 Apr 2005\"\n";
my $MAN_FOOTER = ".SH AUTHOR
The ldns team at NLnet Labs. Which consists out of: 
Jelte Jansen, Erik Rozendaal and Miek Gieben.

.SH REPORTING BUGS
Please report bugs to ldns-team\@nlnetlabs.nl

.SH BUGS
None sofar. This software just works great.

.SH COPYRIGHT
Copyright (c) 2004, 2005 NLnet Labs.
Licensed under the GPL 2. There is NO warranty; not even for
MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.

.SH SEE ALSO
\\fBperldoc Net::DNS\\fR, \\fBRFC1043\\fR,
\\fBRFC1035\\fR, \\fBRFC4033\\fR, \\fBRFC4034\\fR, \\fBRFC4035\\fR.

.SH REMARKS
This manpage was automaticly generated from the ldns source code by
use of Doxygen and some perl.
";

getopts("m:",\%options);
# if -m manpage file is given process that file
# parse the file which tells us what manpages go together
if (defined $options{'m'}) {
	# process
	open(MAN, "<$options{'m'}") or die "Cannot open $options{'m'}";
		# it's line based
		while(<MAN>) {
			chomp;
			if (/^#/) { next; }
			if (/^$/) { next; }
			my @funcs = split /[\t ]*,[\t ]*/, $_;
			$manpages{$funcs[0]} = \@funcs;
			#print "[", $funcs[0], "]\n";
		}
	close(MAN);
} else {
	print "Need -m file to process the .h files\n";
	exit 1;
}

# 0 - somewhere in the file
# 1 - in a doxygen par
# 2 - after doxygen, except funcion

# create our pwd
mkdir "man";
mkdir "man/man$MAN_SECTION";

$state = 0;
while(<>) {
	chomp;
	if (/^\/\*\*[\t ]*$/) {
		# /** Seen
		#print "Comment seen! [$_]\n";
		$state = 1;
		next;
	}
	if (/\*\// and $state == 1) {
		#print "END Comment seen!\n";
		$state = 2;
		next;
	}

	if ($state == 1) {
		# inside doxygen 
		s/^[ \t]*\*[ \t]*//;
		$description = $description . "\n" . $_;
		#$description = $description . "\n.br\n" . $_;
	}
	if ($state == 2 and /const/) {
		# the const word exists in the function call
		$const = "const";
		s/[\t ]*const[\t ]*//;
	} else {
		undef $const;
	}
	
	if (/([\w\*]*)[\t ]+(.*?)\((.*)\);/ and $state == 2) {
		# this should also end the current comment parsing
		$return = $1;
		$key = $2;
		$api = $3;
		# sometimes the * is stuck to the function
		# name instead to the return type
		if ($key =~ /^\*/) {
			#print"Name starts with *\n";
			$key =~ s/^\*//;
			if (defined($const)) {
				$return =  $const . " " . $return . '*';
			} else {
				$return =  $return . '*';
			}
		}
		$description =~ s/\\param\[in\][ \t]*([\*\w]+)[ \t]+/.br\n\\fB$1\\fR: /g;
		$description =~ s/\\param\[out\][ \t]*([\*\w]+)[ \t]+/.br\n\\fB$1\\fR: /g;
		$description =~ s/\\return[ \t]*/.br\nReturns /g;
		
		$description{$key} = $description;
		$api{$key} = $api;
		$return{$key} = $return;
		undef $description;
		$state = 0;
	}
}

# create the manpages
foreach (keys %manpages) {
	$a = $manpages{$_};

	$filename = @$a[0];
	$filename = "man/man$MAN_SECTION/$filename.$MAN_SECTION";

	my $symlink_file = @$a[0] . "." . $MAN_SECTION;

	print $filename,"\n";
	open (MAN, ">$filename") or die "Can not open $filename";

	print MAN  $MAN_HEADER;
	print MAN  ".SH NAME\n";
	print MAN  join ", ", @$a;
	print MAN  "\n\n";
	print MAN  ".SH SYNOPSIS\n";
	print MAN  "#include <ldns/ldns.h>\n";
	print MAN  ".PP\n";

	foreach (@$a) {
		$b = $return{$_};
		$b =~ s/\s+$//;
		print MAN  $b, " ", $_;
		print MAN  "(", $api{$_},");\n";
		print MAN  ".PP\n";
	}
	print MAN  "\n.SH DESCRIPTION\n";

	foreach (@$a) {
		print MAN  ".HP\n";
		print MAN "\\fI", $_, "\\fR", "()"; 
#		print MAN ".br\n";
		print MAN  $description{$_};
		print MAN  "\n.PP\n";
	}

	print MAN $MAN_FOOTER;

	# create symlinks
	chdir("man/man$MAN_SECTION");
	foreach (@$a) {
		my $new_file = $_ . "." . $MAN_SECTION;
		print "\t", $new_file, " -> ", $symlink_file, "\n";
		symlink $symlink_file, $new_file;
	}
	chdir("../.."); # and back
	close(MAN);
}
