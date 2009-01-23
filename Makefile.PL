use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Finance::Bank::IE::PermanentTSB',
    VERSION_FROM      => 'lib/Finance/Bank/IE/PermanentTSB.pm', # finds $VERSION
    PREREQ_PM         => {
        'WWW::Mechanize' => 0,
        'HTML::TokeParser::Simple' => 0,
        'Date::Calc' => 0,
    }, 
    ABSTRACT_FROM  => 'lib/Finance/Bank/IE/PermanentTSB.pm',
    AUTHOR         => 'Angelo "pallotron" Failla <pallotron@freaknet.org>',
    dist           => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean          => { FILES => 't/tmp' },
);
