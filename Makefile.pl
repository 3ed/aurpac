#!/usr/bin/env perl 
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME     => 'AurPac',
    ABSTRACT => "Light'n'fast aur and pacman frontend",
    VERSION_FROM => 'lib/AurPac/Version.pm',
    AUTHOR   => 'Krzysztof AS / 3ED (krzysztof1987@gmail.com)',
    LICENSE  => 'gpl_3',
    MIN_PERL_VERSION => '5.018',
    PREREQ_PM => {
        'ALPM' => 3.00,
        'LWP' => 0,
        "Archive::Extract" => 0
    },
    EXE_FILES => [ qw,script/aurpac, ]
);
