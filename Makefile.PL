use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME	=> 'Data::MultiValuedHash',
	VERSION_FROM => 'Data/MultiValuedHash.pm', # finds $VERSION
	PREREQ_PM => {
	},
);

# This file obviously isn't complete.