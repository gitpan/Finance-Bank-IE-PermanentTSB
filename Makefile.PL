use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Finance::Bank::IE::PermanentTSB',
    VERSION_FROM      => 'lib/Finance/Bank/IE/PermanentTSB.pm', # finds $VERSION
    PREREQ_PM         => {
        'WWW::Mechanize' => 1.34,
        'HTML::TokeParser' => 2.37,
        'Date::Calc' => 5.4,
    }, 
    ABSTRACT_FROM  => 'lib/Finance/Bank/IE/PermanentTSB.pm',
    AUTHOR         => 'Angelo "pallotron" Failla <pallotron@freaknet.org>',
    dist           => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean          => { FILES => 't/tmp Makefile.old' },
);
