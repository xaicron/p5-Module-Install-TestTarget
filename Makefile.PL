use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'Module::Install::TestTarget',
    VERSION_FROM => 'lib/Module/Install/TestTarget.pm',
    ABSTRACT => 'Assembles test targets for `make` with code snippets',
    PREREQ_PM => {
        'ExtUtils::MakeMaker' => 6.31,
        'ExtUtils::Install' => 1.43,
        'Module::Install' => 1.0,
        'Test::More' => 0.96,
        'Test::Requires' => 0,
    },
    test => {
        TESTS => 't/*.t t/*/*.t',
    },
    LICENSE => 'perl',
);
