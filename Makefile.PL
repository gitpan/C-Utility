use strict;
use warnings;
use ExtUtils::MakeMaker;

my $pm = 'lib/C/Utility.pm';
my $repo = 'https://github.com/benkasminbullock/C-Utility';

WriteMakefile (
    NAME => 'C::Utility',
    VERSION_FROM => $pm,
    ABSTRACT_FROM => $pm,
    AUTHOR => 'Ben Bullock <bkb@cpan.org>',
    LICENSE => 'perl',
    PREREQ_PM => {
	'File::Versions' => 0,
    },
    META_MERGE => {
        resources => {
            repository => $repo,
            bugtracker => "$repo/issues",
        },
    },
);
